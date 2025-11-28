base_dir := env("BUILD_BASE_DIR", justfile_directory())
registry_prefix := "ghcr.io/ultramarine-linux"
tag := "main"
image_suffix := "-bootc"

ball variant: (build variant) (rechunk variant)


katsu-live variant:
    #!/usr/bin/bash -x
    VARIANT_NAME=$(just parse_variant {{ variant }})
    mkdir -p output/katsu-live
    rsync -av scripts/katsu-template/ output/katsu-live/
    
    IMAGE_NAME="{{ registry_prefix }}/${VARIANT_NAME}{{ image_suffix }}:{{ tag }}"
    sed -i "s|%BASE_IMAGE%|${IMAGE_NAME}|g" output/katsu-live/bootc-live.yaml
    
    katsu -o iso output/katsu-live/bootc-live.yaml

parse_variant variant:
    #!/usr/bin/bash
    VARIANT="{{ variant }}"
    VARIANT_NAME="${VARIANT##*/}"
    echo "${VARIANT_NAME}"

pull variant:
    #!/usr/bin/bash
    VARIANT_NAME=$(just parse_variant {{ variant }})
    podman pull "{{ registry_prefix }}/${VARIANT_NAME}{{ image_suffix }}:{{ tag }}"

build variant: (parse_variant variant)
    #!/usr/bin/bash -x
    VARIANT_NAME=$(just parse_variant {{ variant }})
    podman build \
    --device=/dev/fuse \
    --cap-add=all \
    --userns=host \
    --cache-from={{ registry_prefix }}/${VARIANT_NAME}{{ image_suffix }} \
    --cgroupns=host \
    --layers=true \
    --security-opt=label=disable -t \
    {{ registry_prefix }}/${VARIANT_NAME}{{ image_suffix }}:{{ tag }}  {{ variant }}

rechunk variant:
    #!/usr/bin/bash -x
    VARIANT_NAME=$(just parse_variant {{ variant }})
    podman run --rm \
        --privileged \
        -v /var/lib/containers:/var/lib/containers \
        "quay.io/centos-bootc/centos-bootc:stream10" \
        /usr/libexec/bootc-base-imagectl rechunk \
        "{{ registry_prefix }}/${VARIANT_NAME}{{ image_suffix }}:{{ tag }}" \
        "{{ registry_prefix }}/${VARIANT_NAME}{{ image_suffix }}:{{ tag }}"

# bootc {variant} {args}
bootc variant *ARGS:
    #!/usr/bin/bash -x
    VARIANT_NAME=$(just parse_variant {{ variant }})
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
        "{{ registry_prefix }}/${VARIANT_NAME}{{ image_suffix }}:{{ tag }}" bootc {{ARGS}}

priv-shell variant:
    #!/usr/bin/bash -x
    VARIANT_NAME=$(just parse_variant {{ variant }})
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
        "{{ registry_prefix }}/${VARIANT_NAME}{{ image_suffix }}":{{ tag }} /bin/bash

build-vm-imb variant type="qcow2":
    #!/usr/bin/bash -x
    VARIANT_NAME=$(just parse_variant {{ variant }})
    just build-vm-legacy "{{ registry_prefix }}/${VARIANT_NAME}{{ image_suffix }}":{{ tag }} "{{ type }}"

build-vm variant:
    #!/usr/bin/bash -x
    if [ ! -e "{{base_dir}}/output/bootable.img" ] ; then
        mkdir -p "{{base_dir}}/output"
        fallocate -l 20G "{{base_dir}}/output/bootable.img"
    fi
    just bootc {{ variant }} install to-disk --via-loopback /data/output/bootable.img --filesystem btrfs --wipe

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
