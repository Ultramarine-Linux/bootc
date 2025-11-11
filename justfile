base_dir := env("BUILD_BASE_DIR", ".")
registry_prefix := "ghcr.io/ultramarine-linux"
build variant:
  buildah bud \
  --device=/dev/fuse \
  --cap-add=all \
  --userns=host \
  --cgroupns=host \
  --security-opt=label=disable -t \
  {{ registry_prefix }}/{{ variant }}-bootc {{ variant }}

  
# bootc {variant} {args}
bootc variant *ARGS:
    sudo podman run \
        --rm --privileged --pid=host \
        -it \
        -v /sys/fs/selinux:/sys/fs/selinux \
        -v /etc/containers:/etc/containers:Z \
        -v /var/lib/containers:/var/lib/containers:Z \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v "{{base_dir}}:/data" \
        --security-opt label=type:unconfined_t \
        "{{ registry_prefix }}/{{ variant }}-bootc" bootc {{ARGS}}

priv-shell variant:
    sudo podman run \
        --rm --privileged --pid=host \
        -it \
        -v /sys/fs/selinux:/sys/fs/selinux \
        -v /etc/containers:/etc/containers:Z \
        -v /var/lib/containers:/var/lib/containers:Z \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v "{{base_dir}}:/data" \
        --security-opt label=type:unconfined_t \
        "{{ registry_prefix }}/{{ variant }}-bootc" /bin/bash

build-vm variant:
    #!/usr/bin/env bash
    if [ ! -e "${base_dir}/output/bootable.img" ] ; then
        mkdir -p "${base_dir}/output"
        fallocate -l 20G "${base_dir}/output/bootable.img"
    fi
    just bootc {{ variant }} install to-disk /data/output/output.img --filesystem btrfs --wipe --help
