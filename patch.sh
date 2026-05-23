#!/bin/bash

set -e

patches="$(readlink -f -- "$1")"
tree="$2"

for project in $(cd "$patches/patches/$tree"; echo *); do
    p="$(tr _ / <<<$project | sed -e 's;platform/;;g')"
    [ "$p" == build ] && p=build/make
    [ "$p" == treble/app ] && p=treble_app
    [ "$p" == vendor/hardware/overlay ] && p=vendor/hardware_overlay
    pushd "$p" &>/dev/null

    for patch in "$patches/patches/$tree/$project"/*.patch; do
        # Ensure no stale in-progress am/rebase state remains in this repo.
        [ -d .git/rebase-apply ] || [ -d .git/rebase-merge ] && git am --abort || true

        if git am -3 "$patch"; then
            continue
        fi

        # If patch is already present upstream/local, skip it cleanly.
        git am --abort || true
        if git apply -R --check "$patch" >/dev/null 2>&1; then
            echo "[WARN] Patch already applied, skipping: $patch"
            continue
        fi

        echo "[ERROR] Failed to apply patch: $patch"
        popd &>/dev/null
        exit 1
    done
    popd &>/dev/null
done
