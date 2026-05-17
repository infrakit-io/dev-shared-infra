#!/usr/bin/env bash
# Generate random capability-based URL for a local dev app instance.
# Writes TUNNEL_HOSTNAME, TUNNEL_HOSTNAME_SPA, DEV_TOKEN to an .env file.
#
# Usage (from the app's directory):
#   BASE_DOMAIN=dev.example.com scripts/init-tunnel-hostname.sh
#   BASE_DOMAIN=dev.example.com scripts/init-tunnel-hostname.sh --keep      # idempotent: keep existing values
#   BASE_DOMAIN=dev.example.com scripts/init-tunnel-hostname.sh --env-file .env.dev   # custom env file
#
# Environment:
#   BASE_DOMAIN   required — wildcard parent domain configured on your CF Tunnel
#                 (e.g., dev.example.com → hostnames will be <slug>.dev.example.com)
#   ENV_FILE      optional — defaults to ./.env

set -euo pipefail

BASE_DOMAIN="${BASE_DOMAIN:-}"
ENV_FILE="${ENV_FILE:-.env}"
KEEP_EXISTING=0

for arg in "$@"; do
  case "$arg" in
    --keep) KEEP_EXISTING=1 ;;
    --env-file) shift; ENV_FILE="$1" ;;
    --env-file=*) ENV_FILE="${arg#--env-file=}" ;;
  esac
done

if [ -z "$BASE_DOMAIN" ]; then
  echo "ERROR: BASE_DOMAIN env var required (e.g., dev.example.com)" >&2
  echo "  Example: BASE_DOMAIN=dev.example.com $0" >&2
  exit 1
fi

if [ "$KEEP_EXISTING" -eq 1 ] && [ -f "$ENV_FILE" ] && grep -q '^TUNNEL_HOSTNAME=' "$ENV_FILE"; then
  echo "→ Existing TUNNEL_HOSTNAME found in $ENV_FILE — keeping"
  grep -E '^(TUNNEL_HOSTNAME|TUNNEL_HOSTNAME_SPA|DEV_TOKEN)=' "$ENV_FILE"
  exit 0
fi

SLUG_API=$(openssl rand -hex 4)
SLUG_SPA=$(openssl rand -hex 4)
HOSTNAME_API="${SLUG_API}.${BASE_DOMAIN}"
HOSTNAME_SPA="${SLUG_SPA}.${BASE_DOMAIN}"
DEV_TOKEN="$SLUG_API"

touch "$ENV_FILE"
grep -v -E '^(TUNNEL_HOSTNAME|TUNNEL_HOSTNAME_SPA|DEV_TOKEN)=' "$ENV_FILE" > "${ENV_FILE}.tmp" || true
mv "${ENV_FILE}.tmp" "$ENV_FILE"
{
  echo "TUNNEL_HOSTNAME=$HOSTNAME_API"
  echo "TUNNEL_HOSTNAME_SPA=$HOSTNAME_SPA"
  echo "DEV_TOKEN=$DEV_TOKEN"
} >> "$ENV_FILE"

echo "→ Generated dev URLs (written to $ENV_FILE):"
echo "  API: https://$HOSTNAME_API"
echo "  SPA: https://$HOSTNAME_SPA"
