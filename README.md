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

The build process is separated into _tiers_, which depend on each other in a linear fashion, starting with the bare minimum base, building up to a full Ultramarine system, desktop variants, and HWE sub-variants for those images.

### Prerequisites

Local builds require Podman, `just`, and a Linux host with the privileges needed for rootful/privileged container builds. Building bootable images additionally requires access to `/dev` and the container storage volume used by Podman. The CI workflows provide the required build tools inside their build containers.

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
just context=tier2/standard ball from=ghcr.io/ultramarine-linux/gnome-bootc:main
```

## Building bootable images

To build a bootable disk image off of the built images, use the `build-vm` or `build-vm-imb` Just recipes:

```bash
just context=tier1/gnome build-vm
```

```bash
just context=tier1/gnome build-vm-imb
```

```bash
just context=tier1/gnome build-vm-imb qcow2 # or raw, vhd, anaconda-iso, bootc-installer, etc.
```

## Notes on building derivatives

Ultramarine bootc stores two copies of the RPM database, one in `/usr/lib/sysimage/rpm` and one in `/usr/share/rpm`. The former is used by the system at runtime, while the latter is used by `rpm-ostree` for rechunking operations. This is a known quirk with rpm-ostree based systems.

The base image provides a DNF 5 action hook that automatically syncs the two databases after transactions, which require the Actions plugin to be installed.
