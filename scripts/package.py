"""Collect native bundles under stable names and build the Arch package."""
import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path


def one(root: Path, pattern: str) -> Path:
    paths = list(root.glob(pattern))
    if len(paths) != 1:
        raise RuntimeError(f"Expected one {pattern} in {root}, found {len(paths)}")
    return paths[0]


def collect(client: Path, output: Path, version: str, platform: str, arch: str):
    output.mkdir(parents=True, exist_ok=True)
    target = client / "src-tauri/target/release"
    bundle = target / "bundle"
    prefix = f"SyntraChat-{version}-{platform}-{arch}"
    if platform == "windows":
        shutil.copy2(one(bundle, "nsis/*-setup.exe"), output / f"{prefix}-setup.exe")
        shutil.copy2(target / "syntrachat.exe", output / f"{prefix}.exe")
    elif platform == "macos":
        app = one(bundle, "macos/*.app")
        shutil.copy2(one(bundle, "dmg/*.dmg"), output / f"{prefix}.dmg")
        subprocess.run([
            "pkgbuild", "--component", str(app), "--install-location", "/Applications",
            "--identifier", "org.syntrachat.desktop", "--version", version,
            str(output / f"{prefix}.pkg"),
        ], check=True)
    else:
        deb = one(bundle, "deb/*.deb")
        for pattern, ext in [("deb/*.deb", "deb"), ("rpm/*.rpm", "rpm"), ("appimage/*.AppImage", "AppImage")]:
            shutil.copy2(one(bundle, pattern), output / f"{prefix}.{ext}")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["dpkg-deb", "-x", str(deb.resolve()), str(root)], check=True)
            size = sum(p.stat().st_size for p in root.rglob("*") if p.is_file())
            (root / ".PKGINFO").write_text(
                f"pkgname = syntrachat\npkgver = {version}-1\npkgdesc = Compact multi-messenger workspace\n"
                f"url = https://github.com/SyntraChat/SyntraChat\nsize = {size}\narch = {arch}\n"
                "license = MIT\ndepend = gtk3\ndepend = webkit2gtk-4.1\ndepend = openssl\ndepend = libayatana-appindicator\n",
                encoding="utf-8",
            )
            subprocess.run([
                "bsdtar", "--zstd", "-cf", str((output / f"{prefix}.pkg.tar.zst").resolve()),
                "-C", str(root), ".PKGINFO", "usr",
            ], check=True)
        # Flatpak wraps the same tested executable in the GNOME dependency runtime.
        flatpak_input = Path("flatpak-input")
        flatpak_input.mkdir(exist_ok=True)
        shutil.copy2(target / "syntrachat", flatpak_input / "syntrachat")
        shutil.copy2(client / "src-tauri/icons/128x128.png", flatpak_input / "org.syntrachat.desktop.png")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--client", type=Path, default=Path("client"))
    parser.add_argument("--output", type=Path, default=Path("release-assets"))
    parser.add_argument("--version", required=True)
    parser.add_argument("--platform", choices=["windows", "linux", "macos"], required=True)
    parser.add_argument("--arch", choices=["x86_64", "aarch64"], required=True)
    args = parser.parse_args()
    collect(args.client, args.output, args.version, args.platform, args.arch)
