#!/usr/bin/env python3
"""Check bootstrap failure propagation and SSH firewall rule probes."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class AccessGuardsTest(unittest.TestCase):
    def test_lockdown_propagates_restart_and_ufw_delete_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            dropin = Path(directory) / "dropin.conf"
            base = (f'source "{ROOT / "scripts/server-lockdown-tailscale.sh"}"; '
                    f'DROPIN="{dropin}"; SSH_PORT=22; '
                    'install() { return 0; }; assert_sshd_policy() { return 0; }; '
                    'assert_listener() { return 0; }; public_ssh_rule_present() { return 0; }; ')
            for failure, expected in (("restart", "restart"), ("delete", "delete")):
                with self.subTest(failure=failure):
                    commands = (
                        f'systemctl() {{ [ "{failure}" != restart ]; }}; '
                        f'ufw() {{ [ "{failure}" != delete ] || [ "$1" != delete ]; }}; '
                        'apply_lockdown'
                    )
                    result = subprocess.run(["/bin/bash", "-c", base + commands], capture_output=True, text=True)
                    self.assertNotEqual(result.returncode, 0)

    def test_only_tailnet_client_ranges_are_accepted(self):
        helper = ROOT / "scripts/lib/tailnet-access.sh"
        cases = {"100.64.0.1": True, "100.127.255.255": True,
                 "fd7a:115c:a1e0::1": True, "100.0.0.1": False,
                 "100.128.0.1": False, "8.8.8.8": False}
        for address, expected in cases.items():
            with self.subTest(address=address):
                result = subprocess.run(["/bin/bash", "-c", f'source "{helper}"; tailnet_client_ip "$1"',
                                         "test", address])
                self.assertEqual(result.returncode == 0, expected)

    def test_bootstrap_verification_fails_on_drift_and_service_error(self):
        with tempfile.TemporaryDirectory() as directory:
            stub_dir = Path(directory)
            for name in ("sshd", "ufw", "fail2ban-client", "systemctl", "sudo", "bash"):
                stub = stub_dir / name
                stub.write_text("#!/bin/sh\n"
                                "if [ \"$TEST_FAIL_SERVICE\" = 1 ] && [ \"$(basename \"$0\")\" = systemctl ]; then exit 1; fi\n"
                                "if [ \"$(basename \"$0\")\" = sudo ]; then printf '%s' \"$TEST_STATUS_OUTPUT\"; fi\n"
                                "exit 0\n")
                stub.chmod(0o755)
            env = {**os.environ, "PATH": f"{stub_dir}:{os.environ['PATH']}",
                   "TEST_FAIL_SERVICE": "0", "TEST_STATUS_OUTPUT": ""}
            script = (f'source "{ROOT / "bootstrap-vps.sh"}"; '
                      'USERNAME=test; USER_HOME=/tmp; ALLOW_PASSWORDLESS_SUDO=0; '
                      'LOCK_SSH_TO_TAILSCALE=0; '
                      'ensure_ssh_access() { return 0; }; test() { return 0; }; id() { return 0; }; '
                      'verify')
            success = subprocess.run(["/bin/bash", "-c", script], env=env, capture_output=True, text=True)
            self.assertEqual(success.returncode, 0, success.stdout + success.stderr)
            env["TEST_STATUS_OUTPUT"] = "M .zshrc\n"
            drift = subprocess.run(["/bin/bash", "-c", script], env=env, capture_output=True, text=True)
            self.assertNotEqual(drift.returncode, 0)
            self.assertIn("Dotfiles differ", drift.stdout)
            env["TEST_STATUS_OUTPUT"] = ""
            env["TEST_FAIL_SERVICE"] = "1"
            service = subprocess.run(["/bin/bash", "-c", script], env=env, capture_output=True, text=True)
            self.assertNotEqual(service.returncode, 0)
            self.assertIn("fail2ban running", service.stdout)

    def test_ufw_public_rules_are_detected(self):
        command = f'source "{ROOT / "scripts/server-lockdown-tailscale.sh"}"; SSH_PORT=22; '
        cases = [
            ("22/tcp                  ALLOW       Anywhere\n", True),
            ("22/tcp (v6)             ALLOW       Anywhere (v6)\n", True),
            ("OpenSSH                 ALLOW       Anywhere\n", True),
            ("Anywhere                ALLOW       Anywhere\n", True),
            ("22/tcp on tailscale0    ALLOW       Anywhere\n", False),
        ]
        for status, should_detect in cases:
            with self.subTest(status=status):
                env = {**os.environ, "TEST_UFW_STATUS": status}
                check = command + 'ufw() { printf "%s" "$TEST_UFW_STATUS"; }; public_ssh_rule_present'
                result = subprocess.run(["/bin/bash", "-c", check], env=env)
                self.assertEqual(result.returncode == 0, should_detect)


if __name__ == "__main__":
    unittest.main()
