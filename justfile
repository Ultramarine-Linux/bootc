registry_prefix = "ghcr.io/ultramarine-linux"
build variant:
  sudo podman build --security-opt=label=disable --cap-add=all --device /dev/fuse -t {{registry_prefix}}/{{variant}}-bootc {{variant}}
  


