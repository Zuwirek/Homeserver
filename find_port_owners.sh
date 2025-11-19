#!/usr/bin/env bash
# Usage: sudo /home/admin/docker/find_port_owners.sh [ports...]
# Default ports checked: 80 81 82 83 8096 8097

PORTS=("${@:-80 81 82 83 8096 8097}")
RX="$(printf ':%s|' "${PORTS[@]}")"
RX="${RX%|}"

echo "1) lsof listeners matching ports: ${PORTS[*]}"
sudo lsof -iTCP -sTCP:LISTEN -P -n | grep -E "$RX" || echo "  (no matches from lsof)"

echo
echo "2) docker ps (all) with PORTS column:"
docker ps -a --format '{{.ID}} {{.Names}} {{.Ports}}' | grep -E "$RX" || echo "  (no containers with those published ports in docker ps)"

echo
echo "3) docker port for each running container that reports a match:"
for id in $(docker ps -q); do
  out="$(docker port "$id" 2>/dev/null || true)"
  if printf '%s\n' "$out" | grep -Eq "$RX"; then
    name="$(docker ps --filter id="$id" --format '{{.Names}}')"
    echo "Container: $id ($name)"
    printf '%s\n' "$out" | grep -E "$RX"
    echo
  fi
done

echo "4) docker-proxy / process info for PIDs that lsof reported:"
PIDS="$(sudo lsof -nP -iTCP -sTCP:LISTEN -P | awk -vrx="$RX" '$9 ~ rx {print $2}' | sort -u || true)"
if [ -n "$PIDS" ]; then
  for p in $PIDS; do
    ps -o pid,ppid,cmd -p "$p" || true
  done
else
  echo "  (no docker-proxy PIDs found via lsof)"
fi

echo
echo "If you find a container ID above, stop it with: docker stop <id> && docker rm <id>"
echo "If a system service (nginx/apache) appears in lsof, stop it with systemctl stop <svc> and disable if desired."
