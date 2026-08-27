#!/usr/bin/env bash
# container-security.sh — Docker/Podman Security Scanning & Hardening Audit
# Usage: sudo bash container-security.sh [--scan] [--audit] [--benchmark]

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${BLUE}[CONTAINER-SEC]${NC} $1"; }
info() { echo -e "${GREEN}[PASS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Detect container runtime (docker or podman)
RUNTIME=""
if command -v docker >/dev/null 2>&1; then
    RUNTIME="docker"
elif command -v podman >/dev/null 2>&1; then
    RUNTIME="podman"
else
    error "Neither docker nor podman found in PATH. Please install a container runtime."
fi

# Runtime privilege checks
is_rootless() {
    # Returns 0 if running rootless, 1 otherwise
    if [ "$RUNTIME" = "podman" ]; then
        if [ "$(id -u)" -ne 0 ]; then return 0; fi
    fi
    return 1
}

# Vulnerability scanning using Trivy if available
scan_vulnerabilities() {
    log "Running image vulnerability scan..."
    if command -v trivy >/dev/null 2>&1; then
        for img in $($RUNTIME images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>'); do
            warn "Scanning $img..."
            trivy image --severity HIGH,CRITICAL --quiet "$img" || true
        done
    else
        warn "Trivy not installed. Install with: apt-get install trivy (or see aquasecurity docs)."
        warn "Skipping CVE scan. You can also use: $RUNTIME scan (if supported)."
    fi
}

# Audit running containers against CIS Docker Benchmark style checks
audit_containers() {
    log "Auditing running $RUNTIME containers against security best practices..."
    local containers
    containers=$($RUNTIME ps -q)
    if [ -z "$containers" ]; then
        warn "No running containers found."
        return
    fi

    for cid in $containers; do
        echo "=========================================="
        local name
        name=$($RUNTIME inspect --format '{{.Name}}' "$cid" | sed 's/^\///')
        log "Container: $name ($cid)"

        # 1. Check privileged mode
        local priv
        priv=$($RUNTIME inspect --format '{{.HostConfig.Privileged}}' "$cid")
        if [ "$priv" = "true" ]; then
            error "[CRITICAL] Container '$name' is running in PRIVILEGED mode."
        else
            info "Not privileged"
        fi

        # 2. Check for added capabilities
        local caps
        caps=$($RUNTIME inspect --format '{{join .HostConfig.CapAdd " "}}' "$cid")
        if [ -n "$caps" ]; then
            warn "Added capabilities: $caps"
        else
            info "No extra capabilities added"
        fi

        # 3. Check user (running as root?)
        local user
        user=$($RUNTIME inspect --format '{{.Config.User}}' "$cid")
        if [ -z "$user" ] || [ "$user" = "0" ] || [ "$user" = "root" ]; then
            warn "Container '$name' runs as root (UID 0). Use a non-root USER in Dockerfile."
        else
            info "Runs as non-root user: $user"
        fi

        # 4. Check read-only root filesystem
        local rofs
        rofs=$($RUNTIME inspect --format '{{.HostConfig.ReadonlyRootfs}}' "$cid")
        if [ "$rofs" = "true" ]; then
            info "Read-only root filesystem enabled"
        else
            warn "Root filesystem is writable. Consider --read-only."
        fi

        # 5. Check privileged port mapping / host network
        local net_mode
        net_mode=$($RUNTIME inspect --format '{{.HostConfig.NetworkMode}}' "$cid")
        if [ "$net_mode" = "host" ]; then
            warn "Container uses host networking (exposes host network stack)."
        else
            info "Network isolation: $net_mode"
        fi

        # 6. Check volume mounts (writable host paths)
        local mounts
        mounts=$($RUNTIME inspect --format '{{json .Mounts}}' "$cid" | grep -o '"Source":"[^"]*"' | sed 's/"Source":"//;s/"//' | head -5)
        if [ -n "$mounts" ]; then
            echo "Mounted volumes:"
            echo "$mounts" | while read -r m; do echo "  - $m"; done
        fi

        # 7. Check memory/CPU limits
        local mem
        mem=$($RUNTIME inspect --format '{{.HostConfig.Memory}}' "$cid")
        if [ "$mem" = "0" ]; then
            warn "No memory limit set (risk of DoS via resource exhaustion)."
        else
            info "Memory limit set: $((mem / 1024 / 1024)) MB"
        fi

        # 8. Check if sensitive host paths mounted (docker.sock)
        if echo "$mounts" | grep -q "docker.sock"; then
            error "[CRITICAL] Container mounts Docker socket — full host compromise risk."
        fi
    done
    echo "=========================================="
}

# Host/daemon benchmark checks
benchmark_host() {
    log "Running $RUNTIME daemon/host security benchmark..."
    echo "------------------------------------------"
    echo "1. Daemon exposure:"
    if [ "$RUNTIME" = "docker" ]; then
        if $RUNTIME info 2>/dev/null | grep -q "Host: tcp://"; then
            error "Docker daemon is exposed over TCP (unencrypted, unauthenticated)."
        else
            info "Docker daemon bound to unix socket only"
        fi
        echo "2. User namespaces:"
        if $RUNTIME info 2>/dev/null | grep -q "userns-remap"; then
            info "User namespace remapping enabled"
        else
            warn "User namespace remapping (userns-remap) not enabled."
        fi
        echo "3. Live restore:"
        if $RUNTIME info 2>/dev/null | grep -q "Live Restore Enabled: true"; then
            info "Live restore enabled"
        else
            warn "Live restore not enabled."
        fi
        echo "4. Default bridge iptables:"
        if $RUNTIME info 2>/dev/null | grep -q "iptables: true"; then
            info "iptables integration enabled"
        else
            warn "iptables integration disabled (network isolation weakened)."
        fi
    else
        info "Podman is daemonless and rootless by default — good baseline."
        if is_rootless; then
            info "Running in rootless mode"
        else
            warn "Running Podman as root. Prefer rootless operation."
        fi
    fi
    echo "------------------------------------------"
}

# Main Dispatcher
case "${1:---scan}" in
    --scan)
        scan_vulnerabilities
        ;;
    --audit)
        audit_containers
        benchmark_host
        ;;
    --benchmark)
        benchmark_host
        ;;
    *)
        echo "Usage: sudo bash container-security.sh [--scan | --audit | --benchmark]"
        exit 1
        ;;
esac
