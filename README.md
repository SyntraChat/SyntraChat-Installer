# SyntraChat Installer

Release packaging and installation for SyntraChat 0.2.0 preview. The release workflow
builds the pinned client revision in `release.json` on native Windows, macOS Intel,
macOS Apple Silicon and Linux runners. Publication waits for every package/check.

| Platform | Packages and GUI | CLI |
| --- | --- | --- |
| Windows x86-64 | NSIS Setup with WebView2 setup, portable EXE | PowerShell; silent per-user Setup |
| macOS 14+ Intel / Apple Silicon | DMG and native graphical PKG | Shell; native `installer` command |
| Linux x86-64 | DEB, RPM, AppImage, Arch pkg.tar.zst, Flatpak; Zenity GUI launcher | Shell; distro package manager or per-user AppImage |

```powershell
irm https://raw.githubusercontent.com/SyntraChat/SyntraChat-Installer/v0.2.0/install.ps1 | iex
```

```sh
curl -fsSL https://raw.githubusercontent.com/SyntraChat/SyntraChat-Installer/v0.2.0/install.sh | sh
```

Download and inspect scripts before execution if preferred. Both scripts use a pinned
version and fail on absent/ambiguous SHA-256 or a mismatched download. They trust GitHub
HTTPS; adjacent checksums are integrity checks, not independent publisher signatures.
No script weakens Gatekeeper, SmartScreen, the WebKit sandbox or system permissions.
macOS builds are ad-hoc signed and **not notarized**; Windows Setup is unsigned.

For a GUI, download the Windows Setup EXE, open the macOS PKG, or unpack the Linux
`*-linux-gui-installer.tar.gz` and run `sh install-gui.sh` (requires Zenity). Linux GUI
installation uses the same checked CLI code and Polkit/pkexec for graphical authentication;
the CLI uses sudo. AppImage needs no administrator privileges.
macOS `sh install.sh --gui` opens the native package installer.

Linux defaults to DEB with apt, RPM with dnf, Arch with pacman, otherwise AppImage:

```sh
sh install.sh --format flatpak  # or deb, rpm, arch, appimage
sh install.sh --dry-run        # print asset URL without downloading/installing
```

Flatpak requires Flatpak plus its GNOME 51 runtime from Flathub. This release does not
register a Flathub app or AUR entry. AppImage uses ~/.local/bin/syntrachat and an application
menu entry; older systems may need FUSE 2. Native Linux binaries target a glibc 2.35+
baseline (Ubuntu 22.04 / Debian 12 and newer); current Arch is supported by its package.
Linux ARM, Windows ARM and macOS before 14 are not included in 0.2.0.
Package-manager installations request sudo. Profiles are preserved; Flatpak uses its own
sandbox data directory. No migration, automated updates or universal rollback is claimed.

0.2.0 includes the tray library through the pinned Flathub shared-modules dependency.
The Flatpak grants only the StatusNotifierWatcher bus name for tray integration, with
no host filesystem or system-bus access. Desktop tray support and global shortcuts vary
by session; startup integration inside Flatpak is not certified.

## Release workflow

Commit `release.json` with the exact 40-character client revision, then push `v0.2.0`.
`.github/workflows/release.yml` builds/checks all targets, validates package metadata and
the Linux launch, checks Windows silent installation, then publishes a complete preview
release here. It never overwrites an existing release. Every asset has SHA256SUMS and
source revisions are recorded in provenance.json. `workflow_dispatch` can retry a failed
build before publication. No cross-repository write token is required.

## Separate signed-manifest verifier

The Rust executable remains a verification-only CLI/library, shipped as
`syntrachat-verifier-*`. The actual installation entry points are the scripts and native
packages above. The verifier requires a trusted build-time key; no fake production key
or test signer is used for these first preview packages.

```powershell
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo run -- --help
```

The verification library authenticates exact manifest bytes with strict Ed25519 before
parsing, validates schema/application/channel/target/SemVer (rejects downgrades), rejects
unsafe filenames including Windows devices and streams, and streams artifact size/SHA-256
checks under a signed limit. Seven automated tests include tampering and malformed data.

Schema 1 (all fields required; unknown fields rejected):

```json
{
  "schema": 1,
  "application": "org.syntrachat.desktop",
  "version": "0.2.0",
  "channel": "stable",
  "target": "x86_64-pc-windows-msvc",
  "artifact": "SyntraChat-0.2.0-x86_64-pc-windows-msvc.exe",
  "sha256": "<64 hexadecimal characters computed from the actual artifact>",
  "size": 123456
}
```

This is a format example, not a valid release manifest. Sign the exact UTF-8 bytes; the
detached signature is raw 64 bytes, not base64/hex. Embed the audited trusted 32-byte
public key as hex **at build time**:

```powershell
$env:SYNTRACHAT_RELEASE_PUBLIC_KEY_HEX = '<trusted public key, 64 hex characters>'
cargo build --release --locked
.\target\release\syntrachat-installer.exe verify manifest.json manifest.sig SyntraChat-0.2.0-x86_64-pc-windows-msvc.exe x86_64-pc-windows-msvc stable 0.0.0
```

No production trust key is supplied. A normal build fails closed when asked to verify.
CLI has no runtime trust-key override. Deterministic test keys exist only in cfg(test).
Private keys stay outside Git. Never trust a checksum/public key fetched alongside a
compromised release. Network replay/expiry, durable installed-version state and key
rotation must be added before a downloader/update manager uses this contract.

Native Setup/PKG and distro package managers own their install lifecycle. The shell
AppImage path uses versioned files and switches its symlink after verification. Tests cover
platform selection, the complete-asset publication gate and tampered downloads. Durable
anti-replay state, signing-key provisioning and rollback remain future updater work.

Client: [SyntraChat](https://github.com/SyntraChat/SyntraChat).
Standards/workflows: [community](https://github.com/SyntraChat/.github).
See the client's docs/RELEASING.md for coordinated release gates.
