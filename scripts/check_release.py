"""Fail closed if any promised release package is absent; checksum exact published bytes."""
import hashlib
import json
import re
from pathlib import Path


def expected_assets(version: str) -> set[str]:
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("Invalid release version")
    prefix = f"SyntraChat-{version}"
    result = {f"{prefix}-windows-x86_64-setup.exe", f"{prefix}-windows-x86_64.exe"}
    for arch in ["x86_64", "aarch64"]:
        result.update(f"{prefix}-macos-{arch}.{ext}" for ext in ["dmg", "pkg"])
    result.update(f"{prefix}-linux-x86_64.{ext}" for ext in ["deb", "rpm", "AppImage", "pkg.tar.zst", "flatpak"])
    result.update({"install.ps1", "install.sh", f"{prefix}-linux-gui-installer.tar.gz"})
    for target in ["windows-x86_64.exe", "linux-x86_64", "macos-x86_64", "macos-aarch64"]:
        result.add(f"syntrachat-verifier-{target}")
    return result


def checksum_release(directory: Path, version: str):
    missing = expected_assets(version) - {p.name for p in directory.iterdir() if p.is_file() and p.stat().st_size}
    if missing:
        raise ValueError(f"Missing release assets: {sorted(missing)}")
    sums = []
    for file in sorted(directory.iterdir()):
        if file.is_file() and file.name != "SHA256SUMS":
            with file.open("rb") as stream:
                digest = hashlib.file_digest(stream, "sha256").hexdigest()
            sums.append(f"{digest}  {file.name}\n")
    (directory / "SHA256SUMS").write_text("".join(sums), encoding="utf-8", newline="\n")


if __name__ == "__main__":
    version = json.loads(Path("release.json").read_text())["version"]
    checksum_release(Path("release-assets"), version)
