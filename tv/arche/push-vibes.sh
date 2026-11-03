#!/usr/bin/env bash
# Put your vibe pictures on the TV: one picture per app, shown while that app has the focus.
#
#   tv/arche/push-vibes.sh <tv ip> <folder of .jpg/.png/.webp>      # replace the TV's vibes with these
#   tv/arche/push-vibes.sh <tv ip> --clear                           # remove them (Home as before)
#
# Pictures are taken in name order: 01-*.jpg goes with the first app in the dock, 02-* with the
# second, and so on, wrapping round. Keep them about 1920x1080 and under 400 KB each so Home stays
# quick. Needs adb on the computer and network debugging on the TV (the phone app shows you how).
set -euo pipefail
HOST="${1:?usage: push-vibes.sh <tv ip> <folder>|--clear}"
SRC="${2:?usage: push-vibes.sh <tv ip> <folder>|--clear}"
PKG=com.gathin.tvhome
DIR=/sdcard/Android/data/$PKG/files/vibes
URI=content://$PKG.theme/vibes
TMP=/data/local/tmp/cyt-vibe

case "$HOST" in *:*) ;; *) HOST="$HOST:5555" ;; esac
adb connect "$HOST" >/dev/null
A=(adb -s "$HOST")

# Remove what is there: through the shell, or the launcher's ThemeProvider where the shell is locked out.
"${A[@]}" shell "for f in $DIR/*; do [ -f \"\$f\" ] && { rm -f \"\$f\" 2>/dev/null || content delete --uri $URI/\${f##*/} 2>/dev/null; }; done; true"

if [ "$SRC" != --clear ]; then
  "${A[@]}" shell "mkdir -p $DIR 2>/dev/null; true"
  n=0
  for f in "$SRC"/*; do
    name=$(basename "$f")
    case "$name" in *.[jJ][pP][gG]|*.[jJ][pP][eE][gG]|*.[pP][nN][gG]|*.[wW][eE][bB][pP]) ;; *) continue ;; esac
    # Plain names only (letters, digits, dot, dash, underscore), as the launcher accepts.
    safe=$(printf '%s' "$name" | tr -c 'A-Za-z0-9._-' '_')
    "${A[@]}" push "$f" "$TMP-$safe" >/dev/null
    # The provider writes the file as the launcher (readable on every Android version); cp is the fallback.
    "${A[@]}" shell "rm -f $DIR/$safe 2>/dev/null; { o=\$(content write --uri $URI/$safe < $TMP-$safe 2>&1) && case \"\$o\" in *'Unsupported operation'*) false ;; esac; } || cp $TMP-$safe $DIR/$safe; rm -f $TMP-$safe"
    n=$((n + 1))
    echo "  $safe"
  done
  echo "$n vibe pictures on the TV"
fi

# Restart Home so it reads the folder again. Not a force-stop: that would switch off the remote's
# key helpers. Home goes to the background, its process is ended, and the Home key brings it back.
"${A[@]}" shell "am start -a android.settings.SETTINGS >/dev/null 2>&1; sleep 2; am kill $PKG; sleep 1; input keyevent KEYCODE_HOME" >/dev/null
echo "done: press Left and Right on the dock to see the vibes change (or restart the TV if they don't show)"
