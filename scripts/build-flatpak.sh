#!/usr/bin/env bash
set -euo pipefail
version=${1:?Release version required}
mkdir -p release-assets
# The sandboxed builder uses the host Flatpak session service to locate SDKs.
flatpak run --command=flatpak-spawn org.flatpak.Builder --host /usr/bin/flatpak info --system org.gnome.Sdk//51
flatpak run org.flatpak.Builder --verbose --force-clean --repo=flatpak-repo flatpak-build packaging/flatpak.json
flatpak build-bundle --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo flatpak-repo "release-assets/SyntraChat-$version-linux-x86_64.flatpak" org.syntrachat.desktop
flatpak install --user --noninteractive "release-assets/SyntraChat-$version-linux-x86_64.flatpak"
flatpak info --user org.syntrachat.desktop
flatpak run --command=sh org.syntrachat.desktop -c 'ldd /app/bin/syntrachat' | tee flatpak-libraries.log
flatpak run --command=sh org.syntrachat.desktop -c 'test -f /app/lib/libayatana-appindicator3.so.1 && ldd /app/lib/libayatana-appindicator3.so.1' | tee -a flatpak-libraries.log
! grep -F 'not found' flatpak-libraries.log
