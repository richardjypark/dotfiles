#!/usr/bin/env bash

# Tailscale IPv4 uses 100.64.0.0/10; Tailscale IPv6 uses fd7a:115c:a1e0::/48.
tailnet_client_ip() {
  local ip second_octet
  ip="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  if [[ "$ip" = fd7a:115c:a1e0:* ]]; then return 0; fi
  if [[ "$ip" =~ ^100\.([0-9]{1,3})\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    second_octet="${BASH_REMATCH[1]}"
    (( 10#$second_octet >= 64 && 10#$second_octet <= 127 ))
    return
  fi
  return 1
}
