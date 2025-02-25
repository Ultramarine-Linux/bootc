#!/bin/bash -x

# Quick-and-dirty script to invoke bootc-image-builder

: ${BOOTC_IMAGE_BUILDER:="quay.io/centos-bootc/bootc-image-builder"}

dirs_check=(
    "output"
    ".cache/rpmmd"
    ".cache/store"
)

cache_dir=$(pwd)/.cache

function create_dirs {
    for dir in ${dirs_check[@]}; do
        mkdir -p $dir
    done
}

function get_uid_gid {
    # Get the UID and GID of the current user
    echo $(id -u):$(id -g)
}

function bootc-image-builder {
    podman run \
        --rm \
        -it \
        --privileged \
        --pull=newer \
        --security-opt label=type:unconfined_t \
        -v $(pwd)/output:/output \
        -v $cache_dir/rpmmd:/rpmmd \
        -v $cache_dir/store:/store \
        -v $(pwd)/scripts:/scripts \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        "$BOOTC_IMAGE_BUILDER" \
        --progress=verbose \
        --chown "$(get_uid_gid)" \
        $@
}

create_dirs
bootc-image-builder $@

