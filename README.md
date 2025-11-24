# Ultramarine Linux - atomic bootc experiment

> [!NOTE]
> This is an experimental version of Ultramarine Linux, based on the new [bootc](https://github.com/containers/bootc) project.
> Do not expect it to be stable or usable for anything other than testing. You have been warned.
>
> Supercedes [Ultramarine-Linux/ostree](https://github.com/Ultramarine-linux/ostree).

Experimental version of Ultramarine Linux, based on bootc.

This image is designed to be a triple-use base for:

- Atomic OS installations (via `bootc install`)
- Standard mutable installations (simply copied to a formatted filesystem layout)
- OCI containers (Podman, Docker, etc.)

Allowing respins and derivatives to be easily built for any of these use cases, while sharing a common base image, meaning the whole filesystem tree can simply be reused and tested once, rather than needing to maintain separate build pipelines for each variant of the OS.

The base image is an OCI/Docker image, which can be consumed to build a disk image or run as a container, or simply extracted to an existing filesystem layout.

## Building

The build process is separated into *tiers*, which depend on each other in a linear fashion, starting with the bare minimum base, building up to a full Ultramarine system, desktop variants, and HWE sub-variants for those images.

Currently there are three tiers:

- Base: The bare minimum bootc-compatible base image
- Tier 0: Stage 2 image, containing minimum variations, a common base for the tier 1 images. Currently only the desktop common base is built.
- Tier 1: Primary Ultramarine images, including but not limited to desktop variants. This is what you will typically use standalone or as a base for your own derivatives.

We provide pre-built base images on GHCR, which can be pulled with Podman or Docker:

```bash
podman pull ghcr.io/ultramarine-linux/base-bootc:latest
```

There's also a Just recipe to quickly pull the image:

```bash
just pull base
```

To build the base image locally, use the Just recipe:

```bash
just ball base
```

This will build the base image from scratch and rechunk it. You can then proceed to build the tier 0 and tier 1 images similarly:

```bash
just ball tier0/desktop
just ball tier1/gnome
```

## Notes on building derivatives

Ultramarine bootc stores two copies of the RPM database, one in `/usr/lib/sysimage/rpm` and one in `/usr/share/rpm`. The former is used by the system at runtime, while the latter is used by `rpm-ostree` for rechunking operations. This is a known quirk with rpm-ostree based systems.

The base image provides a DNF 5 action hook that automatically syncs the two databases after transactions, which require the Actions plugin to be installed.
