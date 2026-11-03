#!/usr/bin/env bash
# Build the Arche fork end to end: the patched TV launcher, signed with the Arche key, pinned into the
# phone app, then the phone app itself. Needs JDK 21 and an Android SDK (ANDROID_HOME) with
# build-tools; GitHub's ubuntu-latest runners have both (.github/workflows/arche.yml runs this).
#
#   tv/arche/build-arche.sh            # writes dist/arche-tv-launcher.apk and dist/arche-phone.apk
#
# Steps: apply tv/arche/launcher/arche-launcher.patch and the res/ files onto the upstream launcher
# (third_party/cleanyourtv), assembleRelease, re-sign with the Arche key (below), copy it
# over android/platform's bundled launcher, rewrite PinnedLauncher in core/trust to its sha256, size
# and signer (verifyLauncherPin then agrees), and assemble the phone app's full debug build.
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT=$PWD
# The launcher signing key: ARCHE_KEYSTORE_B64 (a base64 PKCS12 with alias "arche") and ARCHE_KS_PASS,
# from repository secrets. Without them a throwaway key is made for this build only; a TV then needs
# `adb uninstall com.gathin.tvhome` before the next build's launcher installs over it.
KS="$ROOT/dist/.arche-launcher.p12"
mkdir -p dist
if [ -n "${ARCHE_KEYSTORE_B64:-}" ] && [ -n "${ARCHE_KS_PASS:-}" ]; then
  printf '%s' "$ARCHE_KEYSTORE_B64" | base64 -d > "$KS"
  KS_PASS="$ARCHE_KS_PASS"
else
  echo "::warning::no ARCHE_KEYSTORE_B64 secret: signing the launcher with a throwaway key"
  KS_PASS=$(head -c 18 /dev/urandom | base64 | tr -d '/+=')
  keytool -genkeypair -storetype PKCS12 -keystore "$KS" -storepass "$KS_PASS" -keypass "$KS_PASS" -alias arche \
    -keyalg RSA -keysize 3072 -validity 10000 -dname "O=Arche fork, CN=Arche TV launcher" >/dev/null
fi
trap 'rm -f "$KS"' EXIT
UP=third_party/cleanyourtv
: "${ANDROID_HOME:?set ANDROID_HOME to the Android SDK}"
BT=$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)
mkdir -p dist

echo "==> patch the launcher"
git -C "$UP" checkout -q -- . && git -C "$UP" clean -fdq
git -C "$UP" apply "$ROOT/tv/arche/launcher/arche-launcher.patch"
cp -r tv/arche/launcher/res/. "$UP/launcher/app/src/main/res/"

echo "==> build the launcher"
(
  cd "$UP/launcher"
  echo "sdk.dir=$ANDROID_HOME" > local.properties
  chmod +x gradlew
  ./gradlew assembleRelease --no-daemon --console=plain -PlauncherApplicationId=com.gathin.tvhome
)
RAW=$(ls "$UP"/launcher/app/build/outputs/apk/release/*.apk | head -1)
APK=dist/arche-tv-launcher.apk
"$BT/apksigner" sign --ks "$KS" --ks-pass "pass:$KS_PASS" --ks-key-alias arche --key-pass "pass:$KS_PASS" \
  --v1-signing-enabled false --v2-signing-enabled true --v3-signing-enabled true --out "$APK" "$RAW"
"$BT/apksigner" verify --verbose "$APK" | head -5

SHA=$(sha256sum "$APK" | cut -d' ' -f1)
SIZE=$(stat -c %s "$APK")
SIGNER=$("$BT/apksigner" verify --print-certs "$APK" | sed -n 's/.*certificate SHA-256 digest: //p' | head -1)
VC=$("$BT/aapt2" dump badging "$APK" | sed -n "s/.*versionCode='\([0-9]*\)'.*/\1/p")
VN=$("$BT/aapt2" dump badging "$APK" | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")
echo "launcher: $VN ($VC), $SIZE bytes, sha256 $SHA, signer $SIGNER"

echo "==> pin it into the phone app"
cp "$APK" android/platform/src/main/assets/bundled/cleanyourtv-launcher.apk
python3 - "$SHA" "$SIZE" "$SIGNER" "$VC" "$VN" <<'EOF'
import re, sys
sha, size, signer, vc, vn = sys.argv[1:]
p = "core/trust/src/main/kotlin/tv/cleanyour/core/trust/Pins.kt"
s = open(p).read()
start = s.index("object PinnedLauncher {")
end = s.index("\n}\n", start)
block = s[start:end]
block = re.sub(r'VERSION_CODE = \d+L', f'VERSION_CODE = {vc}L', block)
block = re.sub(r'VERSION_NAME = "[^"]*"', f'VERSION_NAME = "{vn}"', block)
block = re.sub(r'SIZE = [\d_]+L', f'SIZE = {size}L', block)
block = re.sub(r'(?m)^(    const val SHA256 = )"[0-9a-f]{64}"', rf'\1"{sha}"', block)
block = re.sub(r'SIGNER_SHA256 = "[0-9a-f]{64}"', f'SIGNER_SHA256 = "{signer}"', block)
s = s[:start] + block + s[end:]
open(p, "w").write(s)
print(block)
EOF

echo "==> build the phone app"
./gradlew :core:trust:verifyLauncherPin :app:assembleFullDebug --console=plain
cp "$(ls app/build/outputs/apk/full/debug/*.apk | head -1)" dist/arche-phone.apk
ls -l dist
