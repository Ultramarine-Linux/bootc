#!/bin/bash
set -xeuo pipefail


# TODO: Write a preset instead
# this is a hack, remind self to fix later -cappy


systemctl --global enable xdg-user-dirs.service || true
systemctl disable --now sssd-kcm.service sssd-kcm.socket || true
