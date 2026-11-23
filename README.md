# SyntraChat Installer

Independent Rust project, version 0.1.0 foundation preview. **Currently a real signed
release verifier, not yet an installer/uninstaller.** It does not download, install,
execute, elevate, modify package databases or delete files. No GUI or stable Setup.exe
has been produced. Installation/rollback/repair/uninstall remain the next installer gate.

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
  "version": "0.1.0",
  "channel": "stable",
  "target": "x86_64-pc-windows-msvc",
  "artifact": "SyntraChat-0.1.0-x86_64-pc-windows-msvc.exe",
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
.\target\release\syntrachat-installer.exe verify manifest.json manifest.sig SyntraChat-0.1.0-x86_64-pc-windows-msvc.exe x86_64-pc-windows-msvc stable 0.0.0
```

No production trust key is supplied. A normal build fails closed when asked to verify.
CLI has no runtime trust-key override. Deterministic test keys exist only in cfg(test).
Private keys stay outside Git. Never trust a checksum/public key fetched alongside a
compromised release. Network replay/expiry, durable installed-version state and key
rotation must be added before a downloader/update manager uses this contract.

The intended installer architecture is a shared Rust core plus CLI, then an egui/iced
GUI chosen after size/accessibility/platform measurements. Stage within an owned directory,
verify before extraction, reject symlinks/traversal, atomically swap version directories,
retain rollback receipts, and never replace a running executable. Uninstall only owned
files; user-data deletion needs explicit consent. Linux deb/rpm use native package managers;
generic per-user/portable installation needs its own tests. No framework is chosen without
that evaluation.

Client: [SyntraChat](https://github.com/SyntraChat/SyntraChat-Desktop-Tauri).
Standards/workflows: [community](https://github.com/SyntraChat/.github).
See the client's docs/RELEASING.md for coordinated release gates.
