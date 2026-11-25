#!/bin/sh
# curl -fsSL https://raw.githubusercontent.com/SyntraChat/SyntraChat-Installer/v0.1.0/install.sh | sh
set -eu
version=0.1.0
gui=false
dry_run=false
format=auto
while [ "$#" -gt 0 ]; do
    case "$1" in
        --version) [ "$#" -ge 2 ] || { echo 'Missing version' >&2; exit 2; }; version=$2; shift ;;
        --format) [ "$#" -ge 2 ] || { echo 'Missing format' >&2; exit 2; }; format=$2; shift ;;
        --gui) gui=true ;;
        --dry-run) dry_run=true ;;
        --help) echo 'install.sh [--version 0.1.0] [--format auto|appimage|deb|rpm|arch|flatpak] [--gui] [--dry-run]'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
printf '%s\n' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo 'Invalid version' >&2; exit 2; }
os=$(uname -s)
arch=$(uname -m)
case "$os:$arch" in
    Linux:x86_64) platform=linux; arch=x86_64 ;;
    Darwin:x86_64) platform=macos; arch=x86_64 ;;
    Darwin:arm64) platform=macos; arch=aarch64 ;;
    *) echo "Unsupported platform: $os $arch" >&2; exit 1 ;;
esac
if [ "$platform" = macos ]; then
    [ "$format" = auto ] || { echo 'macOS uses the PKG installer.' >&2; exit 2; }
    extension=pkg
else
    if [ "$format" = auto ]; then
        if command -v apt-get >/dev/null 2>&1; then format=deb
        elif command -v dnf >/dev/null 2>&1; then format=rpm
        elif command -v pacman >/dev/null 2>&1; then format=arch
        else format=appimage
        fi
    fi
    case "$format" in
        deb|rpm) extension=$format ;;
        arch) extension=pkg.tar.zst ;;
        appimage) extension=AppImage ;;
        flatpak) extension=flatpak ;;
        *) echo "Unknown package format: $format" >&2; exit 2 ;;
    esac
fi
asset="SyntraChat-$version-$platform-$arch.$extension"
base="https://github.com/SyntraChat/SyntraChat-Installer/releases/download/v$version"
if [ "$dry_run" = true ]; then printf '%s/%s\n' "$base" "$asset"; exit 0; fi
if [ "$gui" = true ]; then
    if [ "$platform" = linux ]; then
        command -v zenity >/dev/null 2>&1 || { echo 'Install zenity for the graphical installer, or omit --gui.' >&2; exit 1; }
        zenity --question --title='Install SyntraChat' --text="Download and install SyntraChat $version ($format)?" || exit 0
    fi
fi
command -v curl >/dev/null 2>&1 || { echo 'curl is required.' >&2; exit 1; }
stage=$(mktemp -d "${TMPDIR:-/tmp}/syntrachat.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
curl --proto '=https' --tlsv1.2 -fsSL "$base/SHA256SUMS" -o "$stage/SHA256SUMS"
[ "$(wc -c < "$stage/SHA256SUMS")" -le 65536 ] || { echo 'Checksum list exceeds size limit.' >&2; exit 1; }
expected=$(awk -v name="$asset" '$2 == name { print $1 }' "$stage/SHA256SUMS")
printf '%s\n' "$expected" | grep -Eq '^[a-fA-F0-9]{64}$' || { echo 'Missing or ambiguous package checksum.' >&2; exit 1; }
curl --proto '=https' --tlsv1.2 -fsSL "$base/$asset" -o "$stage/$asset"
if command -v sha256sum >/dev/null 2>&1; then actual=$(sha256sum "$stage/$asset" | awk '{print $1}')
else actual=$(shasum -a 256 "$stage/$asset" | awk '{print $1}')
fi
[ "$actual" = "$expected" ] || { echo 'Package checksum mismatch. Nothing was installed.' >&2; exit 1; }
if [ "$platform" = macos ]; then
    if [ "$gui" = true ]; then open -W "$stage/$asset"
    else sudo /usr/sbin/installer -pkg "$stage/$asset" -target /
    fi
else
    case "$format" in
        deb) sudo apt-get install -y "$stage/$asset" ;;
        rpm) sudo dnf install -y "$stage/$asset" ;;
        arch) sudo pacman -U --noconfirm "$stage/$asset" ;;
        flatpak) flatpak install --user -y "$stage/$asset" ;;
        appimage)
            install_dir="${XDG_DATA_HOME:-$HOME/.local/share}/syntrachat"
            mkdir -p "$install_dir" "$HOME/.local/bin"
            install -m755 "$stage/$asset" "$install_dir/SyntraChat-$version.AppImage"
            ln -sfn "$install_dir/SyntraChat-$version.AppImage" "$HOME/.local/bin/syntrachat"
            mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
            # Desktop Exec values use double quotes; escape user-supplied HOME characters.
            escaped=$(printf '%s' "$HOME/.local/bin/syntrachat" | sed 's/[\\"`$]/\\&/g; s/%/%%/g')
            printf '[Desktop Entry]\nType=Application\nName=SyntraChat\nExec="%s"\nIcon=internet-chat\nCategories=Network;InstantMessaging;\nTerminal=false\n' "$escaped" > "${XDG_DATA_HOME:-$HOME/.local/share}/applications/org.syntrachat.desktop.desktop"
            ;;
    esac
fi
echo "SyntraChat $version installation completed."
if [ "$gui" = true ] && [ "$platform" = linux ]; then zenity --info --title=SyntraChat --text='Installation completed. Open SyntraChat from your application menu.'; fi
