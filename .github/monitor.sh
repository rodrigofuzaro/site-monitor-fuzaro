#!/usr/bin/env bash
# Checa as URLs em $URLS (+ $URL_TESTE); falha = código fora de 200/301/302/401/403 em 2 tentativas.
set -uo pipefail
: "${NTFY_TOPIC:?secret do tópico ausente}"
read -r -a urls <<< "$URLS"
[ -n "${URL_TESTE:-}" ] && urls+=("$URL_TESTE")
codigo() { local c; c=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "$1") || true; echo "${c:-000}"; }
ok() { case "$1" in 200|301|302|401|403) return 0;; *) return 1;; esac; }
falhas=""
for u in "${urls[@]}"; do
  c=$(codigo "$u")
  if ! ok "$c"; then sleep 10; c=$(codigo "$u"); fi
  if ok "$c"; then echo "OK    $u → $c"; else echo "FALHA $u → $c"; falhas+="$u → $c"$'\n'; fi
done
[ -z "$falhas" ] && exit 0
base="${NTFY_URL:-https://ntfy.sh}"; base="${base%/}"
auth=(); [ -n "${NTFY_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $NTFY_TOKEN")
curl -sS -m 20 -o /dev/null -w 'ntfy http=%{http_code}\n' \
  -H "Title: $TITULO" -H "Priority: 5" -H "Tags: rotating_light" "${auth[@]}" \
  --data-binary "$falhas" "$base/$NTFY_TOPIC" || echo "::error::falha ao enviar para o ntfy"
exit 1
