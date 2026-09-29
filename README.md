# Ultramarine Linux - atomic bootc experiment

> [!NOTE]
> This is an experimental version of Ultramarine Linux, based on the new [bootc](https://github.com/containers/bootc) project.
> Do not expect it to be stable or usable for anything other than testing. You have been warned.
>
> Supersedes [Ultramarine-Linux/ostree](https://github.com/Ultramarine-linux/ostree).

Experimental version of Ultramarine Linux, based on bootc.

This image is designed to be a triple-use base for:

- Atomic OS installations (via `bootc install`)
- Standard mutable installations (simply copied to a formatted filesystem layout)
- OCI containers (Podman, Docker, etc.)

Allowing respins and derivatives to be easily built for any of these use cases, while sharing a common base image, meaning the whole filesystem tree can simply be reused and tested once, rather than needing to maintain separate build pipelines for each variant of the OS.

The base image is an OCI/Docker image, which can be consumed to build a disk image or run as a container, or simply extracted to an existing filesystem layout.

## Building

The build process is separated into _tiers_, which build on each other, starting with the bare minimum base, building up to a full Ultramarine system, desktop variants, and hardware or deployment variants of those desktop images.

### Prerequisites

Local builds require [mkosi](https://github.com/systemd/mkosi) 26 or newer,
Podman, `just`, and a Linux host with the privileges needed for rootful builds.
mkosi builds the image root directly, so unlike the Containerfiles this
replaced it needs root rather than a privileged container. Building bootable
images additionally requires access to `/dev` and the container storage volume
used by Podman. The CI workflows provide the required build tools inside their
build containers.

Version branches use the `umNN` convention. This repository is currently on `um44`; a new version branch is created from the previous version and its release references are updated there.

The image tiers are:

- Base: The bare minimum bootc-compatible base image.
- Tier 0: Stage 2 images containing common server and desktop variations.
- Tier 1: Primary Ultramarine desktop images: GNOME, Xfce, Plasma, and Budgie.
- Tier 2: Hardware or deployment variants built from Tier 1, including standard and NVIDIA images. Additional variants may be present but disabled in CI.

We provide pre-built base images on GHCR, which can be pulled with Podman or Docker:

```bash
podman pull ghcr.io/ultramarine-linux/base-bootc:latest
```

There's also a Just recipe to quickly pull the image:

```bash
just context=base pull
```

To build the base image locally, use the Just recipe:

```bash
just context=base ball
```

This will build the base image from scratch and rechunk it. You can then proceed to build the tier 0, tier 1, and tier 2 images similarly:

```bash
just context=tier0/desktop ball
just context=tier1/gnome ball
just context=tier2/standard ball from=ghcr.io/ultramarine-linux/gnome-bootc:44
```

### How tiers build on each other

Every image is an [mkosi](https://github.com/systemd/mkosi) project. mkosi has
no `FROM`, so a tier derives from the published image of the tier below it
through mkosi's `BaseTrees=` setting. The `basetree` recipe materialises that
image's root filesystem into `<tier>/basetree/`, which is what the tier's
`BaseTrees=basetree` points at:

```bash
just context=tier1/gnome basetree from=ghcr.io/ultramarine-linux/desktop-bootc:44
```

`base` is the exception: it installs from packages and so has no base tree,
which is why `from` is unset for it.

Each tier's `mkosi.conf` keeps only what differs between tiers. Everything the
tiers share lives in `common/`:

- `common/mkosi.conf.d/` holds the Distribution, Build, Validation and Output
  settings, included by every tier. Note that relative paths inside an included
  file resolve against the tier directory, not against `common/`.
- `common/dnf/dnf.conf` is the package-manager configuration for the sandbox
  mkosi runs dnf in. Tiers that need an `exclude=` ship their own complete
  copy, because dnf5 has no `include=` mechanism to layer one on top.

`mkosi` subcommands also work directly against a tier, provided the base tree
is already in place:

```bash
mkosi -C tier1/gnome summary   # show the resolved configuration
mkosi -C tier1/gnome build     # build into tier1/gnome/mkosi.output
```

## Building bootable images

To build a bootable disk image off of the built images, use the `build-vm` or
`build-bib` Just recipes:

```bash
just context=tier1/gnome build-vm
```

```bash
just context=tier1/gnome build-bib
```

```bash
just context=tier1/gnome build-bib qcow2 # or raw, vhd, anaconda-iso, bootc-installer, etc.
```

## Notes on building derivatives

Ultramarine bootc stores two copies of the RPM database, one in `/usr/lib/sysimage/rpm` and one in `/usr/share/rpm`. The former is used by the system at runtime, while the latter is used by `rpm-ostree` for rechunking operations. This is a known quirk with rpm-ostree based systems.

The base image provides a DNF 5 action hook that automatically syncs the two databases after transactions, which require the Actions plugin to be installed.

Every tier sets `CleanPackageMetadata=no` so that `/usr/lib/sysimage/rpm`
survives the build. Without it, dnf could not see what the tier below already
installed, and the image could not itself be used as the base tree of the tier
above. One consequence is that mkosi's `RemovePackages=` is skipped, so a tier
that removes a package does it with dnf in its postinstall script instead.
