import os
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CTL = ROOT / "scripts" / "vless-vpnctl"
FIXTURE_CONFIG = ROOT / "tests" / "fixtures" / "sing-box.sample.json"


def run_ctl(*args: str) -> str:
    env = os.environ.copy()
    env["VLESS_VPN_DRY_RUN"] = "1"
    env["VLESS_VPN_CONFIG"] = str(FIXTURE_CONFIG)
    completed = subprocess.run(
        [str(CTL), *args],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    return completed.stdout


def run_ctl_with_system_path(*args: str) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
    env["VLESS_VPN_DRY_RUN"] = "1"
    env["VLESS_VPN_CONFIG"] = str(FIXTURE_CONFIG)
    return subprocess.run(
        [str(CTL), *args],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def run_ctl_error(*args: str) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["VLESS_VPN_DRY_RUN"] = "1"
    env["VLESS_VPN_CONFIG"] = str(FIXTURE_CONFIG)
    return subprocess.run(
        [str(CTL), *args],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


class VlessVpnCtlTests(unittest.TestCase):
    def test_start_enables_launchdaemon_and_all_proxy_types(self):
        output = run_ctl("start")

        self.assertIn("/bin/launchctl enable system/local.sing-box.tun", output)
        self.assertIn(
            "/bin/launchctl bootstrap system /Library/LaunchDaemons/local.sing-box.tun.plist",
            output,
        )
        self.assertIn("/bin/launchctl kickstart -k system/local.sing-box.tun", output)
        self.assertIn("-setwebproxy", output)
        self.assertIn("-setsecurewebproxy", output)
        self.assertIn("-setsocksfirewallproxy", output)
        self.assertIn("127.0.0.1 7890", output)
        self.assertIn("*.example.com", output)
        self.assertIn("203.0.113.0/24", output)

    def test_stop_disables_proxy_before_stopping_launchdaemon(self):
        output = run_ctl("stop")

        first_proxy_disable = output.index("-setwebproxystate")
        launch_disable = output.index("/bin/launchctl disable system/local.sing-box.tun")
        self.assertLess(first_proxy_disable, launch_disable)
        self.assertIn("-setwebproxystate", output)
        self.assertIn("-setsecurewebproxystate", output)
        self.assertIn("-setsocksfirewallproxystate", output)
        self.assertIn(
            "/bin/launchctl bootout system /Library/LaunchDaemons/local.sing-box.tun.plist",
            output,
        )

    def test_status_outputs_machine_readable_state(self):
        output = run_ctl("status")

        self.assertIn("state=", output)
        self.assertIn("service=", output)
        self.assertIn("http_proxy=", output)
        self.assertIn("https_proxy=", output)
        self.assertIn("socks_proxy=", output)

    def test_add_domain_validates_updates_config_and_restarts(self):
        output = run_ctl("add-domain", "Example.COM")

        self.assertIn("validate_domain example.com", output)
        self.assertIn("update_config domain_suffix example.com", output)
        self.assertIn(f"/opt/homebrew/bin/sing-box check -c {FIXTURE_CONFIG}", output)
        self.assertIn("-setproxybypassdomains", output)
        self.assertIn("example.com", output)
        self.assertIn("/bin/launchctl kickstart -k system/local.sing-box.tun", output)

    def test_add_cidr_validates_updates_config_and_restarts(self):
        output = run_ctl("add-cidr", "203.0.113.4/32")

        self.assertIn("validate_cidr 203.0.113.4/32", output)
        self.assertIn("update_config ip_cidr 203.0.113.4/32", output)
        self.assertIn(f"/opt/homebrew/bin/sing-box check -c {FIXTURE_CONFIG}", output)
        self.assertIn("-setproxybypassdomains", output)
        self.assertIn("203.0.113.4/32", output)
        self.assertIn("/bin/launchctl kickstart -k system/local.sing-box.tun", output)

    def test_invalid_exclusions_are_rejected_before_config_update(self):
        completed = run_ctl_error("add-domain", "bad value")

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("invalid DNS name", completed.stderr)
        self.assertNotIn("update_config", completed.stdout)

    def test_list_exclusions_prints_direct_domains_and_cidrs(self):
        output = run_ctl("list-exclusions")

        self.assertIn("DNS exclusions:", output)
        self.assertIn("CIDR exclusions:", output)
        self.assertIn("example.com", output)
        self.assertIn("203.0.113.0/24", output)

    def test_commands_work_with_macos_system_bash_path(self):
        completed = run_ctl_with_system_path("start")

        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertIn("-setproxybypassdomains", completed.stdout)
        self.assertNotIn("declare: -A", completed.stderr)


if __name__ == "__main__":
    unittest.main()
