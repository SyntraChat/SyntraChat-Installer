import hashlib
import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("check_release", ROOT / "scripts/check_release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def test_missing_package_prevents_release(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                release.checksum_release(Path(directory), "0.1.0")
            self.assertFalse((Path(directory) / "SHA256SUMS").exists())

    def test_complete_release_checksums_exact_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in release.expected_assets("0.1.0"):
                (root / name).write_bytes(name.encode())
            release.checksum_release(root, "0.1.0")
            for line in (root / "SHA256SUMS").read_text().splitlines():
                digest, name = line.split("  ")
                self.assertEqual(digest, hashlib.sha256((root / name).read_bytes()).hexdigest())
            (root / "SyntraChat-0.1.0-linux-x86_64.flatpak").write_bytes(b"")
            with self.assertRaises(ValueError):
                release.checksum_release(root, "0.1.0")

    def test_version_cannot_inject_paths(self):
        for version in ["../other", "0.1.0;echo", "v0.1.0", ""]:
            with self.assertRaises(ValueError):
                release.expected_assets(version)

    def test_flatpak_grants_no_host_filesystem_or_auth_bus(self):
        manifest = json.loads((ROOT / "packaging/flatpak.json").read_text())
        self.assertEqual(manifest["app-id"], "org.syntrachat.desktop")
        self.assertFalse(any("filesystem" in arg or "system-bus" in arg for arg in manifest["finish-args"]))

    @unittest.skipIf(os.name == "nt", "POSIX installer exercised on Linux/macOS CI")
    def test_shell_installer_selects_each_native_format_without_installing(self):
        for package in ["deb", "rpm", "arch", "appimage", "flatpak"]:
            # Explicit format only applies on Linux; macOS is covered below with a fake uname.
            result = subprocess.run(["sh", str(ROOT / "install.sh"), "--dry-run", "--format", package], capture_output=True, text=True)
            if os.uname().sysname == "Linux":
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("/v0.1.0/SyntraChat-0.1.0-linux-x86_64.", result.stdout)

    @unittest.skipIf(os.name == "nt", "POSIX platform detection test")
    def test_shell_installer_selects_mac_arch_and_rejects_unknown_cpu(self):
        with tempfile.TemporaryDirectory() as directory:
            uname = Path(directory) / "uname"
            for system, cpu, expected in [("Darwin", "arm64", "macos-aarch64.pkg"), ("Darwin", "x86_64", "macos-x86_64.pkg"), ("Linux", "riscv64", None)]:
                uname.write_text(f'#!/bin/sh\nif [ "$1" = -s ]; then echo {system}; else echo {cpu}; fi\n')
                uname.chmod(0o755)
                env = dict(os.environ, PATH=directory + os.pathsep + os.environ["PATH"])
                result = subprocess.run(["sh", str(ROOT / "install.sh"), "--dry-run"], env=env, capture_output=True, text=True)
                if expected:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn(expected, result.stdout)
                else:
                    self.assertNotEqual(result.returncode, 0)

    @unittest.skipIf(os.name == "nt", "POSIX filesystem installation test")
    def test_appimage_install_checks_hash_before_creating_launcher(self):
        for tampered in [False, True]:
            with self.subTest(tampered=tampered), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                tools = root / "tools"
                tools.mkdir()
                home = root / "home with spaces"
                home.mkdir()
                fixture = root / "fixture"
                fixture.mkdir()
                asset = "SyntraChat-0.1.0-linux-x86_64.AppImage"
                payload = b"#!/bin/sh\necho fixture-only\n"
                (fixture / asset).write_bytes(payload + (b"tampered" if tampered else b""))
                (fixture / "SHA256SUMS").write_text(hashlib.sha256(payload).hexdigest() + "  " + asset + "\n")
                (tools / "uname").write_text('#!/bin/sh\nif [ "$1" = -s ]; then echo Linux; else echo x86_64; fi\n')
                (tools / "curl").write_text('#!/bin/sh\nwhile [ "$#" -gt 0 ]; do case "$1" in https:*) url=$1;; -o) shift; output=$1;; esac; shift; done\ncp "$FIXTURE/${url##*/}" "$output"\n')
                for file in tools.iterdir():
                    file.chmod(0o755)
                env = dict(os.environ, HOME=str(home), XDG_DATA_HOME=str(home / "data"), FIXTURE=str(fixture), PATH=str(tools) + os.pathsep + os.environ["PATH"])
                result = subprocess.run(["sh", str(ROOT / "install.sh"), "--format", "appimage"], env=env, capture_output=True, text=True)
                launcher = home / ".local/bin/syntrachat"
                if tampered:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(launcher.exists())
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(launcher.read_bytes(), payload)
                    self.assertIn(str(launcher), (home / "data/applications/org.syntrachat.desktop.desktop").read_text())


if __name__ == "__main__":
    unittest.main()
