#!/bin/bash -x

set -euxo pipefail

echo "Setting up SELinux..."

setfiles -m -F -r "${CHROOT}" -c "${CHROOT}"/etc/selinux/targeted/policy/policy.* "${CHROOT}"/etc/selinux/targeted/contexts/files/file_contexts "${CHROOT}"
