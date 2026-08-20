#!/usr/bin/env bash
set -euo pipefail

cd /app

if [[ "${1:-}" == "bootstrap" ]]; then
    shift
    exec /usr/local/bin/bootstrap.sh "$@"
fi
if [[ $# -gt 0 ]]; then
    exec "$@"
fi

if [[ ! -f data/.bcatlas-bootstrap-complete ]]; then
    echo "Initialized data was not found; bootstrapping before service startup."
    /usr/local/bin/bootstrap.sh
fi

for path in data/.bcatlas-bootstrap-complete data/.cocoindex_code/settings.yml data/w1-28-src/graphify-out/graph.json; do
    if [[ ! -f "$path" ]]; then
        echo >&2 "Bootstrap did not produce required file: $path"
        exit 1
    fi
done

pids=()
shutdown() {
    trap - TERM INT EXIT
    if ((${#pids[@]})); then
        kill -TERM "${pids[@]}" 2>/dev/null || true
        wait "${pids[@]}" 2>/dev/null || true
    fi
}
trap shutdown TERM INT EXIT

SEARCH_HOST=127.0.0.1 scripts/start-search-server.sh & pids+=("$!")
GRAPH_HOST=127.0.0.1 scripts/start-graph-server.sh & pids+=("$!")
REGISTRY_HOST=127.0.0.1 scripts/start-registry-server.sh & pids+=("$!")
BUILD_HOST=127.0.0.1 scripts/start-build-server.sh & pids+=("$!")
AGGREGATOR_HOST=0.0.0.0 scripts/start-aggregator.sh & pids+=("$!")

set +e
wait -n "${pids[@]}"
status=$?
set -e
echo >&2 "A bc-code-atlas service exited with status $status; stopping the group."
exit "$status"
