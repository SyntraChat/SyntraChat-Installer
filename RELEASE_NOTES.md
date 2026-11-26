SyntraChat 0.2.0 is an early preview of the compact native multi-messenger workspace.

New in 0.2.0: workspaces, folder groups, pinned accounts, custom account images,
font/spacing/color controls, theme import/export, tray controls, opt-in launch at login,
configurable global show/hide shortcut and session restoration. Mattermost and Zulip
presets accept a server HTTPS URL. Windows app shortcuts now work while embedded services
have focus. Loading and blocked cross-origin navigation have clearer states.

Existing native 0.1.0 settings migrate to schema 2 while preserving account IDs and
profiles. Back up settings before downgrading: 0.1 clients cannot read schema 2.
Startup/global shortcuts depend on OS session support; Flatpak startup integration
is not certified. Tray display requires a desktop tray host (GNOME may need an extension).

This release includes Windows x86-64 Setup and portable EXE; macOS 14+ Intel and Apple
Silicon DMG and graphical PKG; Linux x86-64 DEB, RPM, AppImage, Arch package and Flatpak.
The Linux GUI installer uses Zenity. The Flatpak is a downloadable bundle, not a Flathub listing.
Arch packages are downloadable files, not an AUR registration.

Windows CLI (PowerShell):

```powershell
irm https://raw.githubusercontent.com/SyntraChat/SyntraChat-Installer/v0.2.0/install.ps1 | iex
```

Linux / macOS CLI:

```sh
curl -fsSL https://raw.githubusercontent.com/SyntraChat/SyntraChat-Installer/v0.2.0/install.sh | sh
```

The scripts download only from this tagged release and verify the package SHA-256 before
running the native installer. You can download and inspect the scripts first. Linux can
select `--format deb|rpm|arch|appimage|flatpak`; `--gui` opens graphical confirmation on
Linux or the native Installer app on macOS. Package-manager installs may ask for sudo.
AppImage installs per user. macOS installs into /Applications and requires macOS 14+.

Windows Setup is unsigned. macOS apps are ad-hoc signed, not Apple notarized; Gatekeeper
may prevent launching them. No installer disables OS security checks or clears quarantine.
Checksums detect corruption and are distributed over GitHub HTTPS; they are not independent
publisher signatures. The separate Ed25519 verifier remains fail-closed without a configured
trust key, and is not used to claim that these packages are publisher-authenticated.

Build and package checks run on all four native runner targets before publication. They
do not certify logged-in messaging or cross-account session isolation. Calls, camera,
microphone, downloads and cross-origin sign-in remain restricted in this preview.
Flatpak storage is isolated from native installs. Preview profiles are separate from the
production app identifier; installers do not import or delete existing profiles.

See SHA256SUMS for exact asset hashes and provenance.json for both source revisions.
