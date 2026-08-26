#!/bin/bash
# Tap a node by its accessibility label, or print what is on screen.
#
# Coordinates guessed from a screenshot drift the moment a banner appears or a
# list scrolls, and a mis-tap looks exactly like a bug in the app. This asks the
# device where the thing actually is.
ADB=~/Library/Android/sdk/platform-tools/adb
D="${D:-emulator-5556}"
dump() { "$ADB" -s "$D" shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; "$ADB" -s "$D" shell cat /sdcard/ui.xml 2>/dev/null; }

case "$1" in
  list)
    dump | tr '<' '\n' | grep -oE '(content-desc|text)="[^"]+"' | grep -vE '="[[:space:]]*"' | sort -u
    ;;
  bounds)
    dump | tr '<' '\n' | grep -oE "content-desc=\"$2\"[^>]*bounds=\"\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]\"" \
      | sed -E 's/.*bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]"/\1 \2 \3 \4/' | head -1
    ;;
  *)
    b=$(dump | tr '<' '\n' | grep -oE "content-desc=\"$1\"[^>]*bounds=\"\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]\"" \
        | sed -E 's/.*bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]"/\1 \2 \3 \4/' | head -1)
    if [ -z "$b" ]; then echo "not on screen: $1" >&2; exit 1; fi
    set -- $b
    "$ADB" -s "$D" shell input tap $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 ))
    ;;
esac
