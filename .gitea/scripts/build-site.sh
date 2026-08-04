#!/usr/bin/env bash

set -euo pipefail

readonly venv_dir="/var/lib/gitea-runner/venvs/site"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 SOURCE_DIR" >&2
    exit 2
fi

source_dir=$(realpath "$1")
requirements_file="${source_dir}/.gitea/requirements-site.txt"

if [[ ! -f $requirements_file ]]; then
    echo "Requirements file not found: ${requirements_file}" >&2
    exit 2
fi

mkdir -p "$(dirname "$venv_dir")"
if [[ ! -x "${venv_dir}/bin/python" ]]; then
    python3 -m venv "$venv_dir"
fi

"${venv_dir}/bin/python" -m pip install \
    --disable-pip-version-check \
    --no-input \
    --requirement "$requirements_file"
"${venv_dir}/bin/python" -m pip check
cd "$source_dir"
"${venv_dir}/bin/python" -m mkdocs build --strict
