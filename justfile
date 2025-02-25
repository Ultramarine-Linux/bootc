registry_prefix := "ghcr.io/ultramarine-linux"
build variant:
  buildah bud --cap-add CAP_SYS_ADMIN -t {{ registry_prefix }}/{{ variant }}-bootc {{ variant }}

build-vm image type="qcow2":
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
    --local \
    $TARGET_IMAGE
  sudo chown -R $USER:$USER output
