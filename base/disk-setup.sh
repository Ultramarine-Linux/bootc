#!/bin/bash -x
set -euo pipefail

# Extra setup for disk images

grubby --update-kernel=ALL --args="rhgb quiet"
