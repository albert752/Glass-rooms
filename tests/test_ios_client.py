"""Native iPad client: logic and HTTP client compiled for macOS against the real server (fake HA only)."""

import shutil
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(sys.platform == "darwin" and shutil.which("clang"), "requires macOS clang")
class NativeClientTests(unittest.TestCase):
    def test_native_logic_and_client_against_server(self):
        result = subprocess.run([str(ROOT / "ios" / "scripts" / "test.sh")], capture_output=True, text=True, timeout=240)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(", 0 failures", result.stdout)


if __name__ == "__main__":
    unittest.main()
