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

## Installation/Usage

Images are published to GHCR as `ghcr.io/ultramarine-linux/<edition>-bootc:<tag>`. The tag follows the branch: `rawhide` on `umrawhide`, `45` on `um45`, and so on (`latest` tracks the default branch). Hardware variants get a suffix, e.g. `plasma-bootc:rawhide-nvidia`.

The editions are `plasma`, `gnome` and `xfce`, and the hardware variants are `standard`, `nvidia`, `cachyos` and `surface`.

### Boot images

Live ISOs are built by the [Build ISO images with katsu](https://github.com/Ultramarine-Linux/bootc/actions/workflows/build-iso.yaml) workflow, and you can download them from that run's artifacts. They're still experimental.

You can also boot any other bootc-capable image (e.g. [Fedora CoreOS](https://fedoraproject.org/coreos/)) and install from there.

### Installing Ultramarine bootc

From a booted live image with bootc, install your edition with `bootc install to-disk` (as root):

```bash
<<<<<<< HEAD
bootc install to-disk --source-imgref docker://ghcr.io/ultramarine-linux/plasma-bootc:44 --target-imgref ghcr.io/ultramarine-linux/plasma-bootc:44 /dev/sdX
```

On the Ultramarine live ISO the image is already embedded, so you can install offline from local storage instead:

```bash
bootc install to-disk --source-imgref containers-storage:ghcr.io/ultramarine-linux/plasma-bootc:44-standard --target-imgref ghcr.io/ultramarine-linux/plasma-bootc:44-standard /dev/sdX
```

If `podman images` shows nothing, the embedded store is not being merged into
Podman's own store. Point Podman at it in `/etc/containers/storage.conf`:

```ini
[storage.options]
additionalimagestores = ["/usr/lib/bootc/storage"]
```

On the live ISO this is normally written for you by `livesys-session-extra`; add
it by hand when you are booting the image some other way.

## Building

The build process is separated into _tiers_, which depend on each other in a linear fashion, starting with the bare minimum base, building up to a full Ultramarine system, desktop variants, and hardware sub-variants for those images.

- Base (`base`): The bare minimum bootc-compatible base image, built with [mkosi](https://github.com/systemd/mkosi).
- Tier 0 (`tier0/*`): Common desktop and server layers on top of base.
- Tier 1 (`tier1/*`): The Ultramarine desktop editions: Plasma, GNOME and Xfce.
- Tier 2 (`tier2/*`): Hardware or deployment variants built from Tier 1, like `standard` and `nvidia`. Some variants exist here but aren't built in CI.

### Prerequisites

You need Podman, [`just`](https://github.com/casey/just), and mkosi for the base image. CI pins mkosi to a specific commit, which is in `.github/workflows/reusable-build-image.yml`.

Version branches use the `umNN` convention, and `umrawhide` tracks Rawhide. A new version branch is created from the previous one, and its release references are updated with `just bump-release <N>` (e.g. `just bump-release 46`).

All recipes take `context=<dir>` and tag the result as `ghcr.io/ultramarine-linux/<basename of context>-bootc:<tag>`, so `context=tier1/gnome` produces `gnome-bootc:rawhide`. Set `tag=` to use a different tag.

### Pulling prebuilt images

```bash
just context=base pull                # ghcr.io/ultramarine-linux/base-bootc:rawhide
just context=tier1/plasma tag=44 pull # a different tag
```

### Building locally

The base image is built with mkosi rather than a Containerfile, so `ball` doesn't work for it. Build it, then load the OCI output into Podman under the tag the other tiers expect, and rechunk it:

```bash
sudo just mkosi-build
podman pull "oci:$(find base/mkosi.output -mindepth 1 -maxdepth 1 -type d | head -1)"   # prints the image ID
podman tag <image ID> ghcr.io/ultramarine-linux/base-bootc:rawhide
just context=base chunkah
```

Everything above base is a Containerfile, and `ball` builds and rechunks it. Each tier's `FROM` points at the tag the previous step produced:

```bash
just context=tier0/desktop ball
just context=tier1/plasma ball
just context=tier2/standard from=ghcr.io/ultramarine-linux/plasma-bootc:44 ball
```

Locally, tier 2 images are tagged after their own directory (`standard-bootc:rawhide`), not like CI's `plasma-bootc:rawhide-standard`. Pass `image_tag_override=` if you need the CI name.

You can skip building the lower tiers by pulling them first (e.g. `just context=tier0/desktop pull`).

## Building bootable images

`build-bib` builds a disk image with [bootc-image-builder](https://github.com/osbuild/bootc-image-builder). It copies the image into root's container storage for you and writes the result to `output/`:

```bash
just context=tier1/plasma build-bib        # qcow2
just context=tier1/plasma build-bib raw    # or vmdk, vhd, anaconda-iso, iso, ...
```

`build-vm` runs `bootc install to-disk` against a 20G loopback file at `output/bootable.img`. It needs root and the image in root's storage:

```bash
sudo podman image scp "$USER@localhost::ghcr.io/ultramarine-linux/plasma-bootc:rawhide" root@localhost::
sudo just context=tier1/plasma build-vm
```

`katsu-live` builds a live ISO (`out.iso`) with [Katsu](https://github.com/FyraLabs/katsu) the same way CI does. It needs `katsu` and root, or you can run it inside `ghcr.io/fyralabs/katsu:main`:

```bash
sudo just image_tag=ghcr.io/ultramarine-linux/plasma-bootc:rawhide-standard katsu-live
```

## Notes on building derivatives

Ultramarine bootc stores two copies of the RPM database, one in `/usr/lib/sysimage/rpm` and one in `/usr/share/rpm`. The former is used by the system at runtime, while the latter is used by `rpm-ostree` for rechunking operations. This is a known quirk with rpm-ostree based systems.

The base image provides a DNF 5 action hook that automatically syncs the two databases after transactions, which require the Actions plugin to be installed.
