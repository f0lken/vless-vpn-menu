# VLESS VPN Menu

A small macOS menu bar controller for a local `sing-box` VLESS/Reality VPN setup.

The app does not contain VPN credentials. It controls an existing local `sing-box`
configuration at `/opt/homebrew/etc/sing-box/config.json` and provides a menu bar
UI for:

- starting and stopping the VPN service;
- showing the current VPN/proxy state;
- adding direct-route exclusions by DNS suffix;
- adding direct-route exclusions by IP or CIDR;
- opening the local `sing-box` config.

## Requirements

- macOS 13 or newer
- Xcode Command Line Tools
- Homebrew `sing-box`
- `jq`
- administrator access for `launchd` and network proxy changes

```bash
brew install sing-box jq
```

## Install

```bash
./scripts/install-vless-vpn-app
```

The installer builds and installs:

- `/Applications/VLESS VPN.app`
- `/usr/local/bin/vless-vpnctl`
- `~/Library/LaunchAgents/local.vless-vpn-menu.plist`

## CLI

```bash
sudo vless-vpnctl start
sudo vless-vpnctl stop
vless-vpnctl status
sudo vless-vpnctl add-domain example.com
sudo vless-vpnctl add-cidr 203.0.113.0/24
vless-vpnctl list-exclusions
```

## Configuration

Create your own `sing-box` config from `examples/sing-box.config.example.json`
and install it as:

```bash
sudo install -m 0644 examples/sing-box.config.example.json /opt/homebrew/etc/sing-box/config.json
```

Then replace all placeholder values with your own server address, UUID, Reality
public key, short ID, and SNI.

Do not commit your real `/opt/homebrew/etc/sing-box/config.json`.

## Tests

```bash
python3 -m unittest tests/test_vless_vpnctl.py tests/test_menu_app_source.py
swiftc -framework AppKit -framework Foundation Sources/VLESSVPNMenu/main.swift -o build/VLESSVPN.verify
```
