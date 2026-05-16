import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Sources" / "VLESSVPNMenu" / "main.swift"


class MenuAppSourceTests(unittest.TestCase):
    def test_status_item_uses_compact_square_icon_not_text(self):
        source = SOURCE.read_text()

        self.assertIn("statusItem(withLength: NSStatusItem.squareLength)", source)
        self.assertIn('statusItem.autosaveName = "vless_vpn_status"', source)
        self.assertIn("systemSymbolName:", source)
        self.assertIn("imagePosition = .imageOnly", source)
        self.assertNotIn('statusItem.button?.title = "VPN ON"', source)
        self.assertNotIn('statusItem.button?.title = "VPN OFF"', source)

    def test_menu_contains_exclusion_actions(self):
        source = SOURCE.read_text()

        self.assertIn('NSMenuItem(title: "Исключения"', source)
        self.assertIn('NSMenuItem(title: "Добавить DNS имя..."', source)
        self.assertIn('NSMenuItem(title: "Добавить подсеть/IP..."', source)
        self.assertIn('NSMenuItem(title: "Показать исключения"', source)
        self.assertIn('runPrivileged("add-domain', source)
        self.assertIn('runPrivileged("add-cidr', source)
        self.assertIn('runCommand("list-exclusions"', source)
        self.assertIn("promptForValue", source)

    def test_action_menu_items_do_not_show_checkmarks(self):
        source = SOURCE.read_text()

        self.assertNotIn("startMenuItem.state = .on", source)
        self.assertNotIn("stopMenuItem.state = .on", source)


if __name__ == "__main__":
    unittest.main()
