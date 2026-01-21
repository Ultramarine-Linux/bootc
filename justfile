base_dir := env("BUILD_BASE_DIR", justfile_directory())
registry_prefix := "ghcr.io/ultramarine-linux"
tag := "main"
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

[private]
test:
    echo "Image Tag: {{ image_tag }}"


ball: (build) (rechunk)


katsu-live:
    #!/usr/bin/bash -x
    mkdir -p output/katsu-live
    rsync -av scripts/katsu-template/ output/katsu-live/

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
    #!/usr/bin/bash
    IMG="{{ image_tag }}"
    export CHUNKAH_CONFIG_STR=$(podman inspect $IMG)
    podman run --rm --mount=type=image,src=$IMG,dest=/chunkah -e CHUNKAH_CONFIG_STR quay.io/jlebon/chunkah build | podman load

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
  TARGET_IMAGE={{ image }}

  if ! sudo podman image exists $TARGET_IMAGE ; then
    echo "Ensuring image is on root storage"
    sudo podman image scp $USER@localhost::$TARGET_IMAGE root@localhost::
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
    --installer-payload-ref $TARGET_IMAGE \
    $TARGET_IMAGE
  sudo chown -R $USER:$USER output
