"""Windows installer integration tests using a temporary SteamVR fixture.

Runs the real installer in Windows PowerShell; only SteamVR lookup/process state
are replaced so the tests cannot change the user's SteamVR installation.
"""
import json
import os
from pathlib import Path
import socket
import shutil
import subprocess
import tempfile
import threading
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == "nt", "Windows PowerShell is required")
class SetupTests(unittest.TestCase):
    def setUp(self):
        # mkdir with inherited ACLs also works in restricted Windows workspaces.
        parent = Path(tempfile.gettempdir()).resolve()
        self.base = parent / ("questlhsync-test-" + uuid.uuid4().hex)
        self.base.mkdir(mode=0o777)
        def cleanup():
            resolved = self.base.resolve()
            if resolved.parent != parent or not resolved.name.startswith("questlhsync-test-"):
                raise RuntimeError("unsafe test cleanup path")
            shutil.rmtree(resolved)
        self.addCleanup(cleanup)
        self.settings = self.base / "steamvr.vrsettings"
        self.log = self.base / "calls.txt"
        self.driver = self.base / "driver"
        for name in ("bin/win64/driver_questlhsync.dll", "bin/win64/QuestLHSync.exe",
                     "bin/win64/openvr_api.dll", "driver.vrdrivermanifest"):
            path = self.driver / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"fixture")
        self.fake = self.base / "vrpathreg.ps1"
        self.fake.write_text("$args -join '|' | Add-Content -LiteralPath $env:TEST_LOG\n$global:LASTEXITCODE = 0\n")
        source = (ROOT / "pc/setup.ps1").read_text(encoding="utf-8")
        start = source.index("function Get-SteamVR {")
        end = source.index("function Test-FrameLink(")
        stub = """function Get-SteamVR {
    return @{Exe = $env:TEST_VR; Settings = $env:TEST_SETTINGS}
}
function Get-Process {
    param($Name, $ErrorAction)
    if ($env:TEST_RUNNING -eq '1') { return 'fixture-process' }
}
"""
        self.script = self.base / "setup.ps1"
        self.script.write_text(source[:start] + stub + source[end:], encoding="utf-8")
        self.env = dict(os.environ, TEST_LOG=str(self.log), TEST_VR=str(self.fake),
                        TEST_SETTINGS=str(self.settings), TEST_RUNNING="0")

    def run_setup(self, action="Install", *args):
        return subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
                               "-File", str(self.script), "-Action", action,
                               "-DriverPath", str(self.driver), *args], env=self.env,
                              capture_output=True, timeout=20)

    def test_install_keeps_other_settings_and_backup(self):
        original = {"steamvr": {"test": [1, 2]}, "driver_questlhsync": {"host": "old", "record": True}}
        self.settings.write_text(json.dumps(original))
        result = self.run_setup("Install", "-FrameHost", "192.0.2.1")
        self.assertEqual(result.returncode, 0, result.stderr)
        actual = json.loads(self.settings.read_text())
        self.assertEqual(actual["steamvr"], original["steamvr"])
        self.assertTrue(actual["driver_questlhsync"]["record"])
        self.assertTrue(actual["driver_questlhsync"]["enable"])
        self.assertEqual(actual["driver_questlhsync"]["host"], "192.0.2.1")
        backup, = self.base.glob("*.bak")
        self.assertEqual(json.loads(backup.read_text()), original)
        self.assertIn("adddriver|", self.log.read_text())

    def test_unspecified_host_is_preserved(self):
        self.settings.write_text('{"driver_questlhsync":{"host":"existing"}}')
        self.assertEqual(self.run_setup().returncode, 0)
        self.assertEqual(json.loads(self.settings.read_text())["driver_questlhsync"]["host"], "existing")

    def test_first_install_creates_settings(self):
        self.assertEqual(self.run_setup().returncode, 0)
        self.assertTrue(json.loads(self.settings.read_text())["driver_questlhsync"]["enable"])

    def test_malformed_settings_are_not_overwritten_or_registered(self):
        self.settings.write_text('{broken')
        self.assertNotEqual(self.run_setup().returncode, 0)
        self.assertEqual(self.settings.read_text(), '{broken')
        self.assertFalse(self.log.exists())

    def test_missing_build_does_not_register(self):
        (self.driver / "bin/win64/driver_questlhsync.dll").unlink()
        self.assertNotEqual(self.run_setup().returncode, 0)
        self.assertFalse(self.log.exists())

    def test_running_steamvr_blocks_install_and_remove(self):
        self.env["TEST_RUNNING"] = "1"
        self.assertNotEqual(self.run_setup().returncode, 0)
        self.assertNotEqual(self.run_setup("Remove").returncode, 0)
        self.assertFalse(self.log.exists())

    def test_remove_keeps_settings_and_driver_files(self):
        self.settings.write_text('{"example":true}')
        self.assertEqual(self.run_setup("Remove").returncode, 0)
        self.assertIn("removedriver|", self.log.read_text())
        self.assertEqual(self.settings.read_text(), '{"example":true}')
        self.assertTrue(self.driver.exists())

    def check_hello(self, hello):
        with socket.socket() as listener:
            listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            listener.bind(("127.0.0.1", 47280))
            listener.listen()
            listener.settimeout(15)
            def serve():
                conn, _ = listener.accept()
                with conn:
                    conn.sendall(hello)
            thread = threading.Thread(target=serve, daemon=True)
            thread.start()
            result = self.run_setup("Status", "-FrameHost", "127.0.0.1")
            thread.join(timeout=1)
            return result

    def test_status_accepts_frame_protocol(self):
        result = self.check_hello(b"H QuestLHSync 1 serial=test model=Steam_Frame fw=test module=v1.6\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.settings.exists())

    def test_status_rejects_wrong_headset(self):
        result = self.check_hello(b"H QuestLHSync 1 serial=test model=Quest_Pro fw=test module=v1.6\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.settings.exists())


if __name__ == "__main__":
    unittest.main()
