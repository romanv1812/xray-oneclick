#!/usr/bin/env bash
set -euo pipefail

# =========================
# Defaults (override via env)
# =========================
SNI="${SNI:-www.cloudflare.com}"
DEST="${DEST:-www.cloudflare.com:443}"
SPX="${SPX:-/}"

# If PORT is set, it will be used. Otherwise first free port from list wins.
PORTS_CANDIDATES="${PORTS_CANDIDATES:-9443 8443 2053 2083 2096 2443 3443 4443 5443}"

LOGLEVEL="${LOGLEVEL:-warning}"
TAG="${TAG:-xray-reality}"
# =========================

export DEBIAN_FRONTEND=noninteractive

need_cmd() { command -v "$1" >/dev/null 2>&1; }

apt_install() {
  apt-get update -y >/dev/null
  apt-get install -y "$@" >/dev/null
}

ensure_deps() {
  # Ubuntu/Debian only (apt)
  if ! need_cmd curl; then apt_install curl; fi
  if ! need_cmd openssl; then apt_install openssl; fi
  if ! need_cmd ss; then apt_install iproute2; fi
}

install_or_update_xray() {
  # Official XTLS installer
  bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root >/dev/null
}

pick_free_port() {
  if [[ -n "${PORT:-}" ]]; then
    echo "${PORT}"
    return 0
  fi

  local p
  for p in ${PORTS_CANDIDATES}; do
    if ! ss -lnt "( sport = :$p )" 2>/dev/null | grep -q ":$p"; then
      echo "$p"
      return 0
    fi
  done

  echo "ERROR: No free port found from PORTS_CANDIDATES. Set PORT=xxxx explicitly." >&2
  return 1
}

parse_reality_keys() {
  # Supports both old and new xray x25519 output formats:
  # Old: "Private key:" / "Public key:"
  # New: "PrivateKey:" / "Password:"
  local xray_bin="$1"
  local out priv pbk

  out="$("$xray_bin" x25519)"

  priv="$(printf "%s\n" "$out" | awk -F": *" 'tolower($1) ~ /^(private key)$/ {print $2; exit}')"
  pbk="$(printf "%s\n" "$out"  | awk -F": *" 'tolower($1) ~ /^(public key)$/  {print $2; exit}')"

  [[ -n "${priv:-}" ]] || priv="$(printf "%s\n" "$out" | awk -F": *" 'tolower($1) ~ /^(privatekey)$/ {print $2; exit}')"
  [[ -n "${pbk:-}"  ]] || pbk="$(printf "%s\n" "$out"  | awk -F": *" 'tolower($1) ~ /^(password)$/  {print $2; exit}')"

  if [[ -z "${priv:-}" || -z "${pbk:-}" ]]; then
    echo "ERROR: Failed to parse REALITY keys from 'xray x25519' output:" >&2
    echo "$out" >&2
    return 1
  fi

  echo "PRIV=$priv"
  echo "PBK=$pbk"
}

write_config() {
  local cfg="$1"
  local port="$2"
  local uuid="$3"
  local priv="$4"
  local sid="$5"

  install -d "$(dirname "$cfg")"

  cat > "$cfg" <<EOF
{
  "log": { "loglevel": "${LOGLEVEL}" },
  "inbounds": [{
    "listen": "0.0.0.0",
    "port": ${port},
    "protocol": "vless",
    "settings": {
      "clients": [{ "id": "${uuid}", "flow": "xtls-rprx-vision" }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "${DEST}",
        "xver": 0,
        "serverNames": ["${SNI}"],
        "privateKey": "${priv}",
        "shortIds": ["${sid}"],
        "spiderX": "${SPX}"
      }
    }
  }],
  "outbounds": [{ "protocol": "freedom", "tag": "direct" }]
}
EOF
}

start_and_verify() {
  local port="$1"

  systemctl daemon-reload
  systemctl enable --now xray >/dev/null
  systemctl restart xray >/dev/null

  sleep 0.2
  if ! ss -lnt "( sport = :$port )" 2>/dev/null | grep -q ":$port"; then
    echo "ERROR: Xray is not listening on port $port. Recent logs:" >&2
    journalctl -u xray -n 150 --no-pager >&2 || true
    return 1
  fi
}

ufw_maybe_open_port() {
  local port="$1"

  echo
  echo "===== Firewall (UFW) ====="
  echo "Copy/paste if needed:"
  echo "sudo ufw allow ${port}/tcp"
  echo

  if ! command -v ufw >/dev/null 2>&1; then
    echo "UFW: not installed. If you use a firewall, open TCP ${port} manually."
    return 0
  fi

  local first_line
  first_line="$(ufw status 2>/dev/null | head -n1 || true)"

  if echo "$first_line" | grep -qi "Status: active"; then
    if ufw status 2>/dev/null | grep -Eq "(^|[[:space:]])${port}/tcp([[:space:]]|$)"; then
      echo "UFW: active. Port ${port}/tcp is already allowed."
    else
      echo "UFW: active. Allowing ${port}/tcp..."
      ufw allow "${port}/tcp" >/dev/null
      echo "UFW: rule added for ${port}/tcp."
    fi
  else
    echo "UFW: inactive. No firewall changes applied."
  fi
}

main() {
  ensure_deps
  install_or_update_xray

  local xray_bin="/usr/local/bin/xray"
  local cfg="/usr/local/etc/xray/config.json"

  local uuid port sid ip
  uuid="$("$xray_bin" uuid)"
  port="$(pick_free_port)"
  sid="$(openssl rand -hex 8)"

  local kv priv pbk
  kv="$(parse_reality_keys "$xray_bin")"
  priv="$(printf "%s\n" "$kv" | awk -F= '$1=="PRIV"{print $2}')"
  pbk="$(printf "%s\n" "$kv" | awk -F= '$1=="PBK"{print $2}')"

  write_config "$cfg" "$port" "$uuid" "$priv" "$sid"
  start_and_verify "$port"

  ip="$(curl -4fsS https://api.ipify.org || hostname -I | awk '{print $1}')"

  echo
  echo "===== Shadowrocket (VLESS/REALITY) ====="
  echo "vless://${uuid}@${ip}:${port}?encryption=none&security=reality&sni=${SNI}&fp=chrome&pbk=${pbk}&sid=${sid}&spx=%2F&type=tcp&flow=xtls-rprx-vision#${TAG}"
  echo "======================================="

  ufw_maybe_open_port "$port"

  echo
  echo "IMPORTANT:"
  echo "- Even if UFW is inactive, many VPS providers have an external firewall/security-group."
  echo "- Make sure inbound TCP ${port} is open in your provider panel."
}

main "$@"
