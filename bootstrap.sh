#!/usr/bin/env bash
set -euo pipefail

cd /app

cp -a /opt/bcatlas-data-seed/. data/
git submodule update --init --recursive --depth 1 \
    data/w1-28-src data/docs data/docs-devitpro

git -C data/docs sparse-checkout init --cone
git -C data/docs sparse-checkout set business-central
git -C data/docs-devitpro sparse-checkout init --cone
git -C data/docs-devitpro sparse-checkout set dev-itpro/developer

settings_dir="${COCOINDEX_CODE_DIR:-/root/.cocoindex_code}"
mkdir -p "$settings_dir"
if [[ ! -f "$settings_dir/global_settings.yml" ]]; then
    model="${BCATLAS_EMBEDDING_MODEL:-ibm-granite/granite-embedding-97m-multilingual-r2}"
    device="${BCATLAS_EMBEDDING_DEVICE:-cpu}"
    printf 'embedding:\n  provider: sentence-transformers\n  model: %s\n  device: %s\n' \
        "$model" "$device" > "$settings_dir/global_settings.yml"
    echo "Created $settings_dir/global_settings.yml ($device)."
fi

echo "Building the semantic index. This can take a long time on first run."
(cd data && uv run --project ../tools/cocoindex-code --with-editable ../chunker ccc index)

echo "Building the structural graph."
scripts/rebuild-default-graph.sh
touch data/.bcatlas-bootstrap-complete
echo "Bootstrap complete."
