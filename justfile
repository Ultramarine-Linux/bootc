base_dir := env("BUILD_BASE_DIR", justfile_directory())
registry_prefix := "ghcr.io/ultramarine-linux"
# Ultramarine/Fedora release this branch targets. Bump with `just bump-release <N>`.
release := "rawhide"
tag := release
image_suffix := "-bootc"
context := "base"
variant := file_name(context)
image_tag_override := ""
full_tag := ""
image_tag := if image_tag_override != "" {
    image_tag_override
} else {
    registry_prefix + "/" + variant + image_suffix + ":" + tag
}
from := ""
from_arg := if from != "" {
    "--from=" + from
} else {
    ""
}

# Bump every release reference in the repo, e.g. `just bump-release 45`
bump-release new:
    #!/usr/bin/env bash
    set -euo pipefail
    old="{{ release }}"
    new="{{ new }}"

    if ! [[ "$new" =~ ^[0-9]+$ || "$new" = "rawhide" ]]; then
        echo "error: release must be a number or rawhide, got '$new'" >&2
        exit 1
    fi
    if [ "$new" = "$old" ]; then
        echo "error: already on release $old" >&2
        exit 1
    fi

    cd "{{ justfile_directory() }}"
    echo "Bumping release $old -> $new"

    # justfile itself
    sed -i -E "s/^release := \"$old\"$/release := \"$new\"/" justfile

    # mkosi base: target distro release and tools tree
    sed -i -E "s/^(Release|ToolsTreeRelease)=$old$/\1=$new/" base/mkosi.conf

    # Containerfile base images (only used for local builds; CI passes --from)
    for f in tier*/*/Containerfile; do
        sed -i -E "s#^(FROM ghcr\.io/ultramarine-linux/[a-z0-9-]+):$old\$#\1:$new#" "$f"
    done

    # CI build container and disk image sources
    sed -i -E "s#(ghcr\.io/ultramarine-linux/ultramarine):$old\b#\1:$new#" .github/workflows/reusable-build-image.yml
    sed -i -E "s#(ghcr\.io/ultramarine-linux/[a-z0-9-]+-bootc):$old\b#\1:$new#g" .github/workflows/build-disk.yaml

    # README examples and current branch note
    sed -i -E \
        -e "s#(ghcr\.io/ultramarine-linux/[a-z0-9-]+-bootc):$old\b#\1:$new#g" \
        -e "s#currently on \`um$old\`#currently on \`um$new\`#" \
        README.md

    echo
    echo "Changed files:"
    git status --short

    # Anything still mentioning the old release should be checked by hand
    echo
    echo "Remaining references to $old (review these manually):"
    git grep -nwE "(um|fc|f)?$old" -- . || echo "  none"

    echo
    echo "Next: commit this on a new um$new branch and set it as the default branch when ready."

[private]
test:
    echo "Image Tag: {{ image_tag }}"


ball: (build) (chunkah)

mkosi-build:
    mkosi -C {{ context }} build -B

katsu-live:
    #!/usr/bin/bash -x
    mkdir -p output/
    cp -r scripts/katsu-template/ output/katsu-live/

    IMAGE_NAME="{{ image_tag }}"
    sed -i "s|%BASE_IMAGE%|${IMAGE_NAME}|g" output/katsu-live/bootc-live.yaml

    katsu -o iso output/katsu-live/bootc-live.yaml


pull:
    #!/usr/bin/bash
    podman pull "{{ image_tag }}"

build:
    #!/usr/bin/bash -x
    podman build \
    --device=/dev/fuse \
    --cap-add=all \
    --userns=host \
    {{ from_arg }} \
    --cache-from={{ registry_prefix }}/{{ variant }}{{ image_suffix }} \
    --cgroupns=host \
    --layers=true \
    --security-opt=label=disable -t \
    {{ image_tag }} {{ context }}

rechunk:
    #!/usr/bin/bash -x
    podman run --rm \
        --privileged \
        -v /var/lib/containers:/var/lib/containers \
        "quay.io/centos-bootc/centos-bootc:stream10" \
        /usr/libexec/bootc-base-imagectl rechunk \
        "{{ image_tag }}" \
        "{{ image_tag }}"

chunkah:
    #!/usr/bin/bash -x
    IMG="{{ image_tag }}"
    export CHUNKAH_CONFIG_STR="$(podman inspect "$IMG")"
    MAX_LAYERS=128
    podman run --rm \
        --mount=type=image,source="$IMG",target=/chunkah \
        -e CHUNKAH_CONFIG_STR \
        quay.io/coreos/chunkah build \
        --label ostree.bootable=1 \
        --prune /sysroot/ \
        --max-layers "$MAX_LAYERS" | podman load

# bootc {args}
bootc *ARGS:
    #!/usr/bin/bash -x
    podman run \
        --rm --privileged --pid=host \
        -it \
        --pull=never \
        -v /sys/fs/selinux:/sys/fs/selinux \
        -v /etc/containers:/etc/containers:Z \
        -v /var/lib/containers:/var/lib/containers:Z \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v "{{base_dir}}:/data" \
        --security-opt label=type:unconfined_t \
        "{{ image_tag }}" bootc {{ARGS}}

priv-shell:
    #!/usr/bin/bash -x
    podman run \
        --rm --privileged --pid=host \
        -it \
        -v /sys/fs/selinux:/sys/fs/selinux \
        -v /etc/containers:/etc/containers:Z \
        -v /var/lib/containers:/var/lib/containers:Z \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v "{{base_dir}}:/data" \
        --security-opt label=type:unconfined_t \
        "{{ image_tag }}" /bin/bash

build-bib type="qcow2":
    #!/usr/bin/bash -x
    just image_tag={{ image_tag }} build-vm-legacy {{ image_tag }} {{ type }}

build-vm:
    #!/usr/bin/bash -x
    if [ ! -e "{{base_dir}}/output/bootable.img" ] ; then
        mkdir -p "{{base_dir}}/output"
        fallocate -l 20G "{{base_dir}}/output/bootable.img"
    fi
    just image_tag="{{ image_tag }}" bootc install to-disk --via-loopback /data/output/bootable.img --filesystem btrfs --wipe

build-vm-legacy image type="qcow2":
  #!/usr/bin/env bash
  set -euo pipefail
  TARGET_IMAGE="{{ image }}"

  if ! sudo podman image exists "$TARGET_IMAGE" ; then
    echo "Ensuring image is on root storage"
    sudo podman image scp "$USER@localhost::$TARGET_IMAGE" root@localhost::
  fi

  echo "Cleaning up previous build"
  sudo rm -rf output || true
  mkdir -p output
  sudo podman run \
    --rm \
    -it \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v $(pwd)/image-builder.config.toml:/config.toml:ro \
    -v $(pwd)/output:/output \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type {{ type }} \
    --rootfs btrfs \
    --installer-payload-ref "$TARGET_IMAGE" \
    "$TARGET_IMAGE"
  sudo chown -R "$USER:$USER" output
