# rffmpeg transcode worker for the GXF cluster.
#
# Based on the OFFICIAL jellyfin image so /usr/lib/jellyfin-ffmpeg is the
# EXACT same jellyfin-ffmpeg build the brain emits arguments for
# (ghcr.io/jpvenson/jellyfin.pgsql shares this base). The tag below MUST
# move in lockstep with the brain's Jellyfin version — a version-skewed
# worker fails mid-transcode on CUDA filter/segment options.
FROM jellyfin/jellyfin:10.11.11

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
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
