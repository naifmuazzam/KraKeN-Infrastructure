#!/bin/bash

set -euo pipefail

OUT="/opt/kraken/data/node-exporter/textfile/docker.prom"
TMP="${OUT}.tmp"

{
    echo '# HELP kraken_docker_running_containers Number of currently running Docker containers.'
    echo '# TYPE kraken_docker_running_containers gauge'
    echo "kraken_docker_running_containers $(docker ps -q | wc -l)"

    echo '# HELP kraken_docker_container_restarts_total Number of times a Docker container has restarted.'
    echo '# TYPE kraken_docker_container_restarts_total gauge'

    docker ps -q | while read -r container_id; do
        name=$(docker inspect -f '{{.Name}}' "$container_id" | sed 's#^/##')
        restart_count=$(docker inspect -f '{{.RestartCount}}' "$container_id")

        printf 'kraken_docker_container_restarts_total{container="%s"} %s\n' \
            "$name" "$restart_count"
    done
} > "$TMP"

chown 65534:65534 "$TMP"
chmod 644 "$TMP"

mv "$TMP" "$OUT"
