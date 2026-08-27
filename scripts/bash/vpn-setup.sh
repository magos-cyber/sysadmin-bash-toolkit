#!/usr/bin/env bash
# vpn-setup.sh — WireGuard VPN server setup for homelab
# Usage: sudo bash vpn-setup.sh
# After run: add clients with `wg-add-client.sh <name>` (or wg-quick up wg0)

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

if [[ $EUID -ne 0 ]]; then error "Run as root (sudo)"; fi

log "Installing WireGuard..."
apt-get update && apt-get install -y wireguard wireguard-tools qrencode

# Detect the main outbound interface
EXT_IF=$(ip route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1); exit}')
log "Detected external interface: $EXT_IF"

WG_DIR=/etc/wireguard
mkdir -p "$WG_DIR"
cd "$WG_DIR"

# Server keys
umask 077
wg genkey | tee server_private.key | wg pubkey > server_public.key
SERVER_PRIV=$(cat server_private.key)
SERVER_PUB=$(cat server_public.key)

# Pick a subnet
SERVER_IP="10.10.0.1"

# Build server config
cat > wg0.conf <<EOF
[Interface]
Address = $SERVER_IP/24
ListenPort = 51820
PrivateKey = $SERVER_PRIV
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $EXT_IF -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $EXT_IF -j MASQUERADE
SaveConfig = true
EOF

# Enable IP forwarding
sed -i 's/^#\?net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p

# Firewall
ufw allow 51820/udp
ufw --force enable

# Enable & start
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Helper to add clients
cat > wg-add-client.sh <<'CLIENT'
#!/usr/bin/env bash
# wg-add-client.sh <name> — generate a WireGuard peer and print QR + config
set -euo pipefail
NAME="${1:?Usage: wg-add-client.sh <name>}"
WG_DIR=/etc/wireguard
cd "$WG_DIR"
umask 077
PRIV=$(wg genkey); PUB=$(echo "$PRIV" | wg pubkey)
LAST=$(wg show wg0 allowed-ips 2>/dev/null | grep -oE '10\.10\.0\.[0-9]+' | awk -F. '{print $4}' | sort -n | tail -1)
NEXT=$(( ${LAST:-1} + 1 ))
CLIENT_IP="10.10.0.$NEXT"
SERVER_PUB=$(cat server_public.key)
SERVER_ENDPOINT="$(curl -s ifconfig.me 2>/dev/null):51820"
# Add to server
wg set wg0 peer "$PUB" allowed-ips "$CLIENT_IP/32"
# Write client file
cat > "wg-$NAME.conf" <<EOF
[Interface]
Address = $CLIENT_IP/24
PrivateKey = $PRIV
DNS = 10.10.0.1

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $SERVER_ENDPOINT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF
qrencode -t ansiutf8 < "wg-$NAME.conf"
echo "Config saved: $WG_DIR/wg-$NAME.conf"
CLIENT
chmod +x wg-add-client.sh

log "=========================================="
log "WireGuard VPN installed!"
log "=========================================="
log "Server public key: $SERVER_PUB"
log "Add a client:  wg-add-client.sh phone"
log "Show QR:       cat /etc/wireguard/wg-<name>.conf | qrencode -t ansiutf8"
log "Status:        wg show"
