#!/bin/bash
# SSL Certificate Renewal
# Renew Let's Encrypt certificates and reload services

set -euo pipefail

DOMAINS="${@:-}"
RELOAD_SERVICES="${RELOAD_SERVICES:-nginx traefik}"

echo "=== SSL Certificate Renewal ==="
echo "Date: $(date)"
echo ""

if [ -n "$DOMAINS" ]; then
    # Renew specific domains
    for domain in $DOMAINS; do
        echo "Renewing: $domain"
        certbot renew --cert-name "$domain" --quiet
    done
else
    # Renew all
    echo "Renewing all certificates..."
    certbot renew --quiet
fi

# Reload services
echo ""
echo "Reloading services..."
for service in $RELOAD_SERVICES; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "  Reloading $service..."
        sudo systemctl reload "$service"
    fi
done

echo ""
echo "SSL renewal complete!"
