#!/usr/bin/env python3
"""
port-scanner.py — Lightweight TCP port scanner with optional Telegram alerts.
Usage:
    python3 port-scanner.py --host 192.168.1.1 --ports 22,80,443,51820
    python3 port-scanner.py --host 10.0.0.0/24 --ports 22,80,443 --telegram

Scans common homelab ports and reports open/closed. Useful for verifying
firewall rules after deploying a new service.
"""
import argparse
import socket
import subprocess
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

COMMON_PORTS = {
    22: "SSH", 53: "DNS", 80: "HTTP", 443: "HTTPS", 3000: "Grafana",
    3001: "Uptime-Kuma", 51820: "WireGuard", 8080: "HTTP-Alt",
    8096: "Jellyfin", 9000: "Portainer", 9090: "Prometheus",
}


def expand_hosts(host_arg: str):
    if "/" in host_arg:
        try:
            out = subprocess.run(
                ["nmap", "-n", "-sL", host_arg],
                capture_output=True, text=True, timeout=30,
            ).stdout
            return [
                line.split()[-1]
                for line in out.splitlines()
                if "Nmap scan report" in line
            ]
        except FileNotFoundError:
            print("[WARN] nmap not found; scanning single host only")
            return [host_arg.split("/")[0]]
    return [host_arg]


def scan_port(host: str, port: int, timeout: float) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(timeout)
        return s.connect_ex((host, port)) == 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", required=True, help="IP or CIDR (e.g. 10.0.0.0/24)")
    ap.add_argument("--ports", default=",".join(map(str, COMMON_PORTS.keys())),
                    help="Comma-separated ports or 'common'")
    ap.add_argument("--timeout", type=float, default=0.5)
    ap.add_argument("--telegram", action="store_true")
    ap.add_argument("--bot-token", default="YOUR_BOT_TOKEN")
    ap.add_argument("--chat-id", default="YOUR_CHAT_ID")
    args = ap.parse_args()

    ports = COMMON_PORTS.keys() if args.ports == "common" else [
        int(p) for p in args.ports.split(",") if p.strip()
    ]
    hosts = expand_hosts(args.host)
    open_results = []

    print(f"Scanning {len(hosts)} host(s) on {len(ports)} port(s)...")
    for host in hosts:
        for port in ports:
            with ThreadPoolExecutor(max_workers=50) as ex:
                fut = {ex.submit(scan_port, host, p, args.timeout): p for p in ports}
                for f in fut:
                    p = fut[f]
                    if f.result():
                        svc = COMMON_PORTS.get(p, "unknown")
                        print(f"  [OPEN] {host}:{p} ({svc})")
                        open_results.append(f"{host}:{p} ({svc})")

    print(f"\nFound {len(open_results)} open port(s).")
    if args.telegram and open_results:
        text = "[SEARCH] <b>Port Scan</b>\n" + "\n".join(open_results)
        data = urllib.parse.urlencode({
            "chat_id": args.chat_id, "text": text, "parse_mode": "HTML"
        }).encode()
        urllib.request.urlopen(
            f"https://api.telegram.org/bot{args.bot_token}/sendMessage",
            data=data, timeout=10,
        )


if __name__ == "__main__":
    main()
