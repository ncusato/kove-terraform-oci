#!/bin/bash
# First-boot on BM: copy ssh_authorized_keys from OCI IMDS into every common login user.
# Custom Image Builder RHEL images often omit OCI's default key injection for opc/cloud-user.
set -euo pipefail
TOKEN_URL="http://169.254.169.254/opc/v2/instance/refreshtoken"
MD_URL="http://169.254.169.254/opc/v2/instance/metadata/ssh_authorized_keys"
V1_URL="http://169.254.169.254/opc/v1/instance/metadata/ssh_authorized_keys"
STACK_KEYS_B64='${stack_ssh_authorized_keys_b64}'

KEYS=""
KEYS=$(curl -sf --connect-timeout 5 -H "Authorization: Bearer Oracle" "$V1_URL" || true)
if [ -z "$KEYS" ]; then
  TOK=$(curl -sf --connect-timeout 5 -X PUT "$TOKEN_URL" -H "Authorization: Bearer Oracle" || true)
  if [ -n "$TOK" ]; then
    KEYS=$(curl -sf --connect-timeout 5 -H "Authorization: Bearer Oracle" -H "Opc-Instance-Metadata-Token: $TOK" "$MD_URL" || true)
  fi
fi
if [ -n "$STACK_KEYS_B64" ]; then
  STACK_KEYS=$(echo "$STACK_KEYS_B64" | base64 -d 2>/dev/null || true)
  [ -n "$STACK_KEYS" ] && KEYS="$${KEYS}"$'\n'"$${STACK_KEYS}"
fi
[ -z "$(echo "$KEYS" | tr -d '[:space:]')" ] && exit 0

install_keys() {
  local u="$1"
  id "$u" &>/dev/null || return 0
  local hs
  hs=$(getent passwd "$u" | cut -d: -f6)
  [ -n "$hs" ] && [ -d "$hs" ] || return 0
  install -d -m 700 -o "$u" -g "$u" "$hs/.ssh"
  local ak="$hs/.ssh/authorized_keys"
  if [ ! -f "$ak" ]; then
    touch "$ak"
  fi
  chmod 600 "$ak"
  chown "$u:$u" "$ak"
  while IFS= read -r line || [ -n "$line" ]; do
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$line" ] && continue
    grep -qxF "$line" "$ak" 2>/dev/null || echo "$line" >> "$ak"
  done <<< "$KEYS"
  chown "$u:$u" "$ak"
  chmod 600 "$ak"
}

for u in opc cloud-user ec2-user; do
  install_keys "$u" || true
done
