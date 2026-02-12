xray-oneclick

One-liner installer for Xray-core with VLESS + REALITY (XTLS Vision).
Prints a ready-to-import vless:// link for Shadowrocket.

OS support

Ubuntu / Debian (APT)

Quick start (one-liner)

Run:
```
bash <(curl -fsSL https://raw.githubusercontent.com/romanv1812/xray-oneclick/main/install.sh)
```

Configuration (environment variables)

You can override defaults by setting environment variables before running the one-liner:

PORT — force a specific port (example: 9443)

PORTS_CANDIDATES — space-separated ports to try when PORT is not set
default: 9443 8443 2053 2083 2096 2443 3443 4443 5443

SNI — REALITY SNI (default: www.cloudflare.com
)

DEST — REALITY destination host:port (default: www.cloudflare.com:443
)

SPX — REALITY spiderX (default: /)

TAG — link name after # in the generated URL (default: xray-reality)

LOGLEVEL — Xray log level (default: warning)

Example (fixed port):
PORT=9443 TAG=my-node bash <(curl -fsSL https://raw.githubusercontent.com/romanv1812/xray-oneclick/main/install.sh
)

Example (custom SNI/DEST):
SNI=www.cloudflare.com
 DEST=www.cloudflare.com:443
 bash <(curl -fsSL https://raw.githubusercontent.com/romanv1812/xray-oneclick/main/install.sh
)

What the script does

Installs/updates Xray-core using the official XTLS installer

Generates a VLESS UUID

Generates REALITY keys via: xray x25519
Supports both formats:

old: Private key / Public key

new: PrivateKey / Password (PBK for clients)

Writes config to: /usr/local/etc/xray/config.json

Enables and starts the xray systemd service

Prints a vless:// link for Shadowrocket import

Firewall notes

The script always prints a copy/paste command:
sudo ufw allow <port>/tcp

If UFW is active, the script will automatically add the rule for the chosen port.
If UFW is inactive, it will not change anything.

Even with UFW inactive, many VPS providers have an external firewall/security group — open the chosen TCP port there too.

Troubleshooting
Shadowrocket shows timeout

Most commonly the chosen port is blocked externally (provider firewall/security group).

Check that Xray is listening:
ss -lntp | grep -E ':(9443|8443|2053|2083|2096|2443|3443|4443|5443)\b'

Check logs:
journalctl -u xray -n 200 --no-pager

Verify whether packets reach the server when tapping “Test” in Shadowrocket:
tcpdump -ni any tcp port <YOUR_PORT>

If 0 packets arrive: open inbound TCP <YOUR_PORT> in your provider panel firewall/security group.

If packets arrive but still fails: inspect the Xray logs.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
