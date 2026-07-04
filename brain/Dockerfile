# jellyfin.pgsql + rffmpeg "brain" layer for the GXF cluster.
#
# Adds what the jpvenson image lacks for rffmpeg: python3 (+click/yaml/
# psycopg2 for the PostgreSQL state backend) and an ssh client, plus the
# rffmpeg shim symlinked as ffmpeg/ffprobe. The base's entrypoint
# (database.xml templating from POSTGRES_* env) is preserved untouched.
#
# The base tag MUST match the worker image's Jellyfin version.
FROM ghcr.io/jpvenson/jellyfin.pgsql:10.11.11-1

# Pin rffmpeg by commit for reproducible builds. master is the supported
# line (the only tagged release, v1/2022, is pre-refactor legacy).
# Update deliberately; last reviewed 2026-07-04 (master @ Nov 2025).
ARG RFFMPEG_REF=master

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 python3-yaml python3-click python3-psycopg2 \
        openssh-client ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL \
        "https://raw.githubusercontent.com/joshuaboniface/rffmpeg/${RFFMPEG_REF}/rffmpeg.py" \
        -o /usr/local/bin/rffmpeg \
    && chmod +x /usr/local/bin/rffmpeg \
    # ffprobe path is regex-DERIVED from the ffmpeg path by Jellyfin —
    # both symlinks must exist in the same dir, extensionless.
    && ln -s /usr/local/bin/rffmpeg /usr/local/bin/ffmpeg \
    && ln -s /usr/local/bin/rffmpeg /usr/local/bin/ffprobe \
    && mkdir -p /etc/rffmpeg /var/lib/rffmpeg

# The official base pins JELLYFIN_FFMPEG=/usr/lib/jellyfin-ffmpeg/ffmpeg
# (env beats encoding.xml, so editing EncoderAppPath would silently do
# nothing). Repoint it at the rffmpeg shim; local fallback ffmpeg stays
# available at /usr/lib/jellyfin-ffmpeg/ffmpeg for rffmpeg's
# fallback_ffmpeg_command.
ENV JELLYFIN_FFMPEG=/usr/local/bin/ffmpeg
