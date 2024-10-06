# registry_auth := "auth.json"
# ostree_cache := "/cache"
# ostree_repo := "ostree-repo"
# initialize := "--initialize"
# images_dir := "/images"

# prep:
#   [ -d {{ostree_cache}} ] || mkdir -p {{ostree_cache}}
#   [ -d {{ostree_repo}} ] || ostree init --repo={{ostree_repo}}
#   [ -d {{images_dir}} ] || mkdir -p {{images_dir}}

# clean-cache:
#   sudo rm -rf {{ ostree_cache }}

# clean-variant variant:
#   rm -rf ./out/{{variant}}

# clean-out:
#   rm -rf ./out

# clean-repo:
#   rm -rf ./{{ostree_repo}}

# clean-images:
#   rm -rf ./{{images_dir}}

# clean: clean-cache clean-out clean-repo clean-images

# compile variant: (clean-variant variant)
#   melody compile ultramarine/{{variant}}.yaml out/{{variant}}

# compose-tree variant:
#   sudo rpm-ostree compose tree --cachedir={{ostree_cache}} --repo={{ostree_repo}} --unified-core out/{{variant}}/0.yaml

# compose-image variant:
#   sudo rpm-ostree compose image --cachedir={{ostree_cache}} {{initialize}} out/{{variant}}/0.yaml {{images_dir}}/$(echo "{{variant}}" | tr / -)-{{arch()}}.tar

# build-tree variant: prep (compile variant) (compose-tree variant)
# build-image variant: prep (compile variant) (compose-image variant)

image_name := "ghcr.io/ultramarine/base-standalone-bootc"

build-base-standalone:
  sudo podman build --security-opt=label=disable --cap-add=all --device /dev/fuse -t {{image_name}} base-standalone 


  

