#!/usr/bin/env bash

set -euo pipefail

readonly deploy_root="/srv/de-roadmap"
readonly releases_root="${deploy_root}/releases"
readonly keep_releases=3

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 SITE_DIR COMMIT_SHA-RUN_ID" >&2
    exit 2
fi

source_dir=$(realpath "$1")
release_id=$2

if [[ ! $release_id =~ ^[0-9a-f]{40}-[0-9]+$ ]]; then
    echo "Invalid release id: ${release_id}" >&2
    exit 2
fi

if [[ ! -f "${source_dir}/index.html" ]]; then
    echo "Built site has no index.html: ${source_dir}" >&2
    exit 2
fi

if [[ ! -d $releases_root || ! -w $releases_root || ! -w $deploy_root ]]; then
    echo "Deployment directories are missing or not writable" >&2
    exit 1
fi

readonly release_dir="${releases_root}/${release_id}"
readonly staging_dir="${releases_root}/.${release_id}.tmp"
readonly next_link="${deploy_root}/.current.${release_id}.tmp"

if [[ -e $release_dir || -e $staging_dir || -e $next_link ]]; then
    echo "Release path already exists: ${release_id}" >&2
    exit 1
fi

cleanup() {
    rm -rf -- "$staging_dir"
    rm -f -- "$next_link"
}
trap cleanup EXIT

umask 0022
mkdir "$staging_dir"
cp -a "${source_dir}/." "$staging_dir/"
chmod -R u=rwX,go=rX "$staging_dir"
mv "$staging_dir" "$release_dir"

ln -s "releases/${release_id}" "$next_link"
mv -Tf "$next_link" "${deploy_root}/current"

mapfile -t old_releases < <(
    find "$releases_root" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -regextype posix-extended \
        -regex '.*/[0-9a-f]{40}-[0-9]+' \
        -printf '%T@ %f\n' \
        | sort -nr \
        | awk -v keep="$keep_releases" 'NR > keep { print $2 }'
)

for old_release in "${old_releases[@]}"; do
    if [[ $old_release =~ ^[0-9a-f]{40}-[0-9]+$ && $old_release != "$release_id" ]]; then
        rm -rf -- "${releases_root:?}/${old_release}"
    fi
done

trap - EXIT
echo "Published release ${release_id}"
