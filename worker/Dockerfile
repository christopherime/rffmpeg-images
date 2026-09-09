# rffmpeg transcode worker (sshd + jellyfin-ffmpeg receiver).
#
# Based on the OFFICIAL jellyfin image so /usr/lib/jellyfin-ffmpeg is the
# EXACT same jellyfin-ffmpeg build the brain emits arguments for
# (the 10.11 brain's jpvenson base shares it; the 12.0 brain is built
# FROM this same official image). The tag below MUST move in lockstep
# with the brain's Jellyfin version — a version-skewed worker fails
# mid-transcode on CUDA filter/segment options, and 12.0 replaces
# FFmpeg 7 with 8.1.2, which is exactly such a skew.
#
# Parameterised so one Dockerfile serves both lines; CI passes it per
# matrix entry. The default keeps the 10.11 build byte-identical.
ARG JELLYFIN_VERSION=10.11.11
FROM jellyfin/jellyfin:${JELLYFIN_VERSION}

RUN apt-get update \
    && apt-get install -y --no-install-recommends openssh-server \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd /root/.ssh \
    && chmod 700 /root/.ssh

# GPU: driver libraries are injected by the nvidia runtimeClass at run
# time; the worker only needs the capability request.
ENV NVIDIA_DRIVER_CAPABILITIES=compute,video,utility

COPY sshd_rffmpeg.conf /etc/ssh/sshd_config.d/rffmpeg.conf
COPY entrypoint.sh /entrypoint.sh

# Upstream's ForceCommand allowlist wrapper (docs/HARDENING, PR #99):
# only ffmpeg/ffprobe binaries can be executed over SSH, everything else
# is rejected and logged. Enforced via the authorized_keys entry:
#   command="/usr/local/bin/limited-wrapper.py",restrict ssh-ed25519 ...
# (the key file comes from the k8s Secret — put the prefix THERE).
ARG RFFMPEG_REPO=https://raw.githubusercontent.com/joshuaboniface/rffmpeg
ARG RFFMPEG_REF=f54ac843c7c8a157562e7ce37aaebbc5cb41354e
RUN apt-get update && apt-get install -y --no-install-recommends python3 curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL "${RFFMPEG_REPO}/${RFFMPEG_REF}/hardening/limited-wrapper.py" \
        -o /usr/local/bin/limited-wrapper.py \
    && chmod 755 /usr/local/bin/limited-wrapper.py \
    && chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
