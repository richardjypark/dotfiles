#!/usr/bin/env python3
"""Check bootstrap failure propagation and SSH firewall rule probes."""

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
LOCKDOWN = ROOT / "scripts/server-lockdown-tailscale.sh"
PERSONAL_CLOUD = ROOT / "scripts/setup-personal-cloud-tailscale.sh"


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


class LockdownRollbackTest(unittest.TestCase):
    """Order of --confirm, the rollback timer, and rollback.sh in both lockdown scripts."""

    def setUp(self):
        self._temp = tempfile.TemporaryDirectory()
        self.root = Path(self._temp.name)
        self.calls = self.root / "calls.log"
        stubs = self.root / "stubs"
        stubs.mkdir()
        for name in ("ufw", "nft", "systemctl", "flock"):
            stub = stubs / name
            stub.write_text('#!/bin/sh\necho "$(basename "$0") $*" >> "$CALLS"\n'
                            '[ "$(basename "$0") $1" != "systemctl stop" ] || exit "${STOP_STATUS:-0}"\n')
            stub.chmod(0o755)
        self.env = {**os.environ, "PATH": f"{stubs}:{os.environ['PATH']}", "CALLS": str(self.calls)}

    def tearDown(self):
        self._temp.cleanup()

    def logged(self):
        return self.calls.read_text().splitlines() if self.calls.exists() else []

    def write(self, relative, text):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def rollback_script(self, script):
        # The real rollback.sh text with every host path moved under the test root.
        body = script.read_text().split("<<'SCRIPT'\n", 1)[1].split("\nSCRIPT\n", 1)[0] + "\n"
        body = re.sub(r"(?<![\w.])/(etc|run|usr/local)/", lambda m: f"{self.root}/{m.group(1)}/", body)
        self.assertNotRegex(body, r"(?<![\w./-])/(etc|run|usr/local)/")
        return self.write("rollback.sh", body)

    def run_bash(self, command, *args):
        return subprocess.run(["bash", "-c", command, "test", *args], env=self.env,
                              capture_output=True, text=True)

    def lockdown_state(self):
        self.write("etc/ssh/sshd_config.d/90-tailscale-lockdown.conf", "Port 22\n")
        self.write("etc/ufw/user.rules", "lockdown\n")
        self.write("run/dotfiles-ssh-lockdown/dropin", "Port 2200\n")
        self.write("run/dotfiles-ssh-lockdown/ufw/user.rules", "prior\n")
        self.write("run/dotfiles-ssh-lockdown/ufw-prior-status", "active\n")

    def test_rollback_restores_the_snapshot_under_the_lock(self):
        self.lockdown_state()
        result = self.run_bash('bash "$1"', str(self.rollback_script(LOCKDOWN)))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "etc/ssh/sshd_config.d/90-tailscale-lockdown.conf").read_text(), "Port 2200\n")
        self.assertEqual((self.root / "etc/ufw/user.rules").read_text(), "prior\n")
        self.assertFalse((self.root / "run/dotfiles-ssh-lockdown").exists())
        calls = self.logged()
        self.assertTrue(calls and calls[0].startswith("flock "), calls)
        self.assertIn("ufw reload", calls)
        self.assertIn("systemctl restart sshd", calls)

    def test_rollback_after_confirmation_changes_nothing(self):
        self.lockdown_state()
        subprocess.run(["rm", "-rf", str(self.root / "run/dotfiles-ssh-lockdown")], check=True)
        result = self.run_bash('bash "$1"', str(self.rollback_script(LOCKDOWN)))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "etc/ssh/sshd_config.d/90-tailscale-lockdown.conf").read_text(), "Port 22\n")
        self.assertEqual((self.root / "etc/ufw/user.rules").read_text(), "lockdown\n")
        self.assertEqual([call.split()[0] for call in self.logged()], ["flock"])

    @unittest.skipUnless(shutil.which("flock"), "util-linux flock is not installed")
    def test_rollback_waits_for_confirm_with_the_real_lock(self):
        self.lockdown_state()
        rollback = self.rollback_script(LOCKDOWN)
        lock_file = self.root / "run/dotfiles-ssh-lockdown.lock"
        env = {**self.env, "PATH": ":".join(p for p in self.env["PATH"].split(":")
                                            if not p.endswith("/stubs"))}
        (self.root / "real-stubs").mkdir()
        for name in ("ufw", "systemctl"):
            shutil.copy(self.root / "stubs" / name, self.root / "real-stubs" / name)
        env["PATH"] = f"{self.root / 'real-stubs'}:{env['PATH']}"
        holder = subprocess.Popen(["flock", str(lock_file), "sh", "-c", "read line"], stdin=subprocess.PIPE)
        try:
            for _ in range(100):
                if subprocess.run(["flock", "-n", str(lock_file), "true"]).returncode != 0:
                    break
                time.sleep(0.05)
            waiting = subprocess.Popen(["bash", str(rollback)], env=env)
            time.sleep(0.5)
            self.assertIsNone(waiting.poll(), "rollback.sh must wait for the lock")
            # --confirm removes the state directory while it holds the lock.
            shutil.rmtree(self.root / "run/dotfiles-ssh-lockdown")
        finally:
            holder.communicate(b"\n", timeout=10)
        self.assertEqual(waiting.wait(timeout=10), 0)
        self.assertEqual((self.root / "etc/ssh/sshd_config.d/90-tailscale-lockdown.conf").read_text(), "Port 22\n")
        self.assertEqual(self.logged(), [])

    def test_rollback_stops_when_the_firewall_status_is_missing(self):
        self.lockdown_state()
        (self.root / "run/dotfiles-ssh-lockdown/ufw-prior-status").unlink()
        result = self.run_bash('bash "$1"', str(self.rollback_script(LOCKDOWN)))
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("ufw disable", self.logged())
        self.assertNotIn("systemctl restart sshd", self.logged())

    def test_failed_lockdown_keeps_the_timer_until_the_restore_ends(self):
        for rollback_status, expected in ((0, ["rollback", "systemctl stop dotfiles-ssh-rollback-7.timer"]),
                                          (1, ["rollback"])):
            with self.subTest(rollback_status=rollback_status):
                self.calls.unlink(missing_ok=True)
                state = self.root / "state"
                self.write("state/unit", "dotfiles-ssh-rollback-7\n")
                self.write("state/rollback.sh", f'echo rollback >> "$CALLS"\nexit {rollback_status}\n')
                result = self.run_bash(f'source "{LOCKDOWN}"; STATE_DIR="$1"; rollback_now', str(state))
                self.assertEqual(result.returncode != 0, rollback_status != 0, result.stderr)
                self.assertEqual(self.logged(), expected)

    def confirm(self, script, state_files, setup):
        state = self.root / "state"
        for name, text in state_files.items():
            self.write(f"state/{name}", text)
        command = (f'source "{script}"; STATE_DIR="$1"; LOCK_FILE="$2"; SSH_PORT=22; '
                   'SSH_CONNECTION="100.64.0.9 50001 100.64.0.1 22"; '
                   f'{setup} confirm_lockdown')
        return state, self.run_bash(command, str(state), str(self.root / "confirm.lock"))

    def test_confirm_holds_the_lock_and_tolerates_a_fired_timer(self):
        self.env["STOP_STATUS"] = "5"
        cases = (
            (LOCKDOWN, {"port": "22\n", "unit": "dotfiles-ssh-rollback-7\n",
                        "initial-session": "100.64.0.9 50000 100.64.0.1 22\n"},
             'assert_sshd_policy() { echo assert >> "$CALLS"; }; assert_listener() { :; }; '
             'assert_ufw_policy() { :; };', "dotfiles-ssh-rollback-7"),
            (PERSONAL_CLOUD, {"unit-name": "dotfiles-personal-cloud-rollback-7\n",
                              "initial-session": "100.64.0.9 50000 100.64.0.1 22\n"},
             'assert_access() { echo assert >> "$CALLS"; };', "dotfiles-personal-cloud-rollback-7"),
        )
        for script, files, setup, unit in cases:
            with self.subTest(script=script.name):
                self.calls.unlink(missing_ok=True)
                state, result = self.confirm(script, files, setup)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("confirmed", result.stdout)
                self.assertFalse(state.exists())
                calls = self.logged()
                self.assertTrue(calls and calls[0].startswith("flock "), calls)
                self.assertEqual(calls[1:], ["assert", f"systemctl stop {unit}.timer"])

    def test_confirm_after_a_finished_rollback_changes_nothing(self):
        for script in (LOCKDOWN, PERSONAL_CLOUD):
            with self.subTest(script=script.name):
                self.calls.unlink(missing_ok=True)
                _, result = self.confirm(script, {}, "")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("No pending lockdown", result.stderr)
                self.assertEqual([call.split()[0] for call in self.logged()], ["flock"])

    def personal_cloud_state(self):
        for path in ("etc/ssh/sshd_config.d/90-tailscale-hardening.conf", "etc/nftables.d/dotfiles-ssh.nft",
                     "usr/local/sbin/dotfiles-ssh-nft-apply", "etc/systemd/system/dotfiles-ssh-firewall.service"):
            self.write(path, "lockdown\n")
        for name in ("sshd", "table.nft"):
            self.write(f"run/dotfiles-personal-cloud-lockdown/{name}", "prior\n")
        self.write("run/dotfiles-personal-cloud-lockdown/table-state", "present\n")
        self.write("run/dotfiles-personal-cloud-lockdown/unit-prior-state", "disabled\n")

    def test_personal_cloud_rollback_after_confirmation_changes_nothing(self):
        self.personal_cloud_state()
        subprocess.run(["rm", "-rf", str(self.root / "run/dotfiles-personal-cloud-lockdown")], check=True)
        result = self.run_bash('bash "$1"', str(self.rollback_script(PERSONAL_CLOUD)))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "etc/ssh/sshd_config.d/90-tailscale-hardening.conf").read_text(), "lockdown\n")
        self.assertEqual((self.root / "etc/nftables.d/dotfiles-ssh.nft").read_text(), "lockdown\n")
        self.assertEqual([call.split()[0] for call in self.logged()], ["flock"])

    def test_personal_cloud_rollback_stops_when_the_table_state_is_missing(self):
        self.personal_cloud_state()
        (self.root / "run/dotfiles-personal-cloud-lockdown/table-state").unlink()
        result = self.run_bash('bash "$1"', str(self.rollback_script(PERSONAL_CLOUD)))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(call.startswith("nft ") for call in self.logged()), self.logged())

    def test_personal_cloud_failed_lockdown_keeps_the_timer_until_the_restore_ends(self):
        state = self.root / "state"
        self.write("state/unit-name", "dotfiles-personal-cloud-rollback-7\n")
        self.write("state/rollback.sh", 'echo rollback >> "$CALLS"\n')
        result = self.run_bash(f'source "{PERSONAL_CLOUD}"; STATE_DIR="$1"; rollback_now', str(state))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.logged(), ["rollback", "systemctl stop dotfiles-personal-cloud-rollback-7.timer"])


if __name__ == "__main__":
    unittest.main()
