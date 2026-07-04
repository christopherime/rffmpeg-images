#!/bin/bash
# rffmpeg worker entrypoint: install the brain's public key from the
# mounted Secret, generate host keys if absent, run sshd in foreground.
set -euo pipefail

# Host keys are pod-ephemeral by design — rffmpeg connects with
# StrictHostKeyChecking=no (its default), so regeneration is harmless.
ssh-keygen -A

# authorized_keys arrives via Secret mount (subPath-safe: copy, don't link)
if [ -f /ssh/authorized_keys ]; then
    install -m 600 /ssh/authorized_keys /root/.ssh/authorized_keys
else
    echo "WARNING: /ssh/authorized_keys not mounted — no one can log in" >&2
fi

# NVIDIA JIT cache (scale_cuda/tonemap_cuda) must stay off NFS: point it
# at the pod-local scratch (emptyDir mounted at /nvcache by the chart).
mkdir -p /nvcache
ln -sfn /nvcache /root/.nv

exec /usr/sbin/sshd -D -e
