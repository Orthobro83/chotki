#!/usr/bin/env bash
set -euo pipefail

# Package already-built release binaries on the target Ubuntu architecture.
# This is an alpha proof; clean-install and licensing gates still apply.
if [[ $# -ne 3 ]]; then
    echo "Usage: package-deb.sh /path/to/chotki-linux /path/to/ChotkiLinuxBridge output-dir" >&2
    exit 2
fi

window=$(realpath "$1")
helper=$(realpath "$2")
output=$(realpath -m "$3")
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
arch=$(dpkg --print-architecture)
version=${CHOTKI_PACKAGE_VERSION:-0.1.0~alpha1}
package="$output/chotki_${version}_${arch}.deb"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

command -v dpkg-deb >/dev/null
command -v dpkg-query >/dev/null
command -v ldd >/dev/null
[[ -x "$window" && -x "$helper" ]] || { echo "Release binaries are missing" >&2; exit 1; }

install -d "$stage/DEBIAN" "$stage/usr/bin" "$stage/usr/lib/chotki/swift" \
    "$stage/usr/share/applications" \
    "$stage/usr/share/icons/hicolor/1024x1024/apps" \
    "$stage/usr/share/doc/chotki"
install -m755 "$window" "$stage/usr/lib/chotki/chotki-linux"
install -m755 "$helper" "$stage/usr/lib/chotki/ChotkiLinuxBridge"
install -m644 "$repo_root/ios/Chotki/Assets.xcassets/AppIcon.appiconset/icon-1024.png" \
    "$stage/usr/share/icons/hicolor/1024x1024/apps/org.chotki.Chotki.png"
install -m644 "$repo_root/LICENSE" "$stage/usr/share/doc/chotki/LICENSE"
install -m644 "$repo_root/linux/app/ui/fonts/LICENSE.txt" \
    "$stage/usr/share/doc/chotki/XCharter-LICENSE.txt"

cat > "$stage/usr/bin/chotki" <<'SH'
#!/bin/sh
set -eu
export LD_LIBRARY_PATH="/usr/lib/chotki/swift${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
mode=--normal
if [ "${1:-}" = --review ]; then mode=--review; shift; fi
exec /usr/lib/chotki/chotki-linux "$mode" /usr/lib/chotki/ChotkiLinuxBridge "$@"
SH
chmod 755 "$stage/usr/bin/chotki"

cat > "$stage/usr/share/applications/org.chotki.Chotki.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Chotki
Comment=An Orthodox rule of prayer
Exec=chotki
Icon=org.chotki.Chotki
Terminal=false
Categories=Education;Religion;
StartupWMClass=Chotki
DESKTOP

mapfile -t libraries < <(ldd "$window" "$helper" | awk '$2 == "=>" && $3 ~ /^\// {print $3}' | sort -u)
dependencies=()
swift_license=""
for library in "${libraries[@]}"; do
    if [[ "$library" == */lib/swift/linux/* ]]; then
        install -m755 "$library" "$stage/usr/lib/chotki/swift/$(basename "$library")"
        swift_usr=${library%%/lib/swift/linux/*}
        swift_license="$swift_usr/share/swift/LICENSE.txt"
    else
        resolved=$(realpath "$library")
        owner=$(dpkg-query -S "$resolved" 2>/dev/null | head -n1 | cut -d: -f1 || true)
        [[ -n "$owner" ]] || { echo "No package owns $resolved" >&2; exit 1; }
        dependencies+=("$owner")
    fi
done
[[ -n "$swift_license" && -f "$swift_license" ]] || {
    echo "Swift runtime license was not found" >&2
    exit 1
}
install -m644 "$swift_license" "$stage/usr/share/doc/chotki/Swift-LICENSE.txt"
dependencies+=(qt6-qpa-plugins qml6-module-qtquick qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts qml6-module-qtquick-templates \
    qml6-module-qtqml-models \
    qml6-module-qtqml-workerscript)
depends=$(printf '%s\n' "${dependencies[@]}" | sort -u | paste -sd, -)

cat > "$stage/DEBIAN/control" <<CONTROL
Package: chotki
Version: $version
Section: education
Priority: optional
Architecture: $arch
Maintainer: Chotki project <noreply@github.com>
Depends: $depends
Description: Chotki Linux desktop alpha
 A desktop shell for the Chotki prayer rule. This alpha package is for
 technical review and is not yet a complete port of the macOS application.
CONTROL

mkdir -p "$output"
dpkg-deb --build --root-owner-group "$stage" "$package"
dpkg-deb --info "$package"
echo "$package"
