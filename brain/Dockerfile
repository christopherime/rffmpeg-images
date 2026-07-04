# jellyfin.pgsql + rffmpeg "brain" layer for the GXF cluster.
#
# Adds what the jpvenson image lacks for rffmpeg (verified 2026-07-04 by
# code review of both projects): python3 + click/yaml/psycopg2 (psycopg2
# is REQUIRED when the RFFMPEG_POSTGRES_* env vars are set — the import
# is conditional-on-env but unguarded, a missing module means ImportError
# on every transcode) and an ssh client, plus the rffmpeg shim symlinked
# as ffmpeg/ffprobe. The base's entrypoint (database.xml templating from
# POSTGRES_* env + plugin recopy, which keeps the plugin ABI-synced with
# the server on upgrades) is preserved untouched.
#
# The base tag MUST match the worker image's Jellyfin version.
FROM ghcr.io/jpvenson/jellyfin.pgsql:10.11.11-1

# rffmpeg pinned by commit (master HEAD f54ac843, 2025-11-03 — the only
# tagged release, v1/2022, is pre-refactor legacy; master is the
# supported line). NOTE: the entrypoint file is `rffmpeg` — NO .py
# extension since the repo reorganization.
ARG RFFMPEG_REPO=https://raw.githubusercontent.com/joshuaboniface/rffmpeg
ARG RFFMPEG_REF=f54ac843c7c8a157562e7ce37aaebbc5cb41354e

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 python3-yaml python3-click python3-psycopg2 \
        openssh-client ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL "${RFFMPEG_REPO}/${RFFMPEG_REF}/rffmpeg" \
        -o /usr/local/bin/rffmpeg \
    && curl -fsSL "${RFFMPEG_REPO}/${RFFMPEG_REF}/rffmpeg.yml.sample" \
        -o /etc/rffmpeg/rffmpeg.yml.sample 2>/dev/null \
        || mkdir -p /etc/rffmpeg \
    && chmod +x /usr/local/bin/rffmpeg \
    # rffmpeg dispatches on argv[0] SUBSTRING: "rffmpeg" -> management
    # CLI, "ffprobe" -> probe mode, else ffmpeg mode. The symlinks are
    # therefore extensionless and must NOT live under a directory whose
    # path contains "rffmpeg" (issue #94 failure mode).
    && ln -s /usr/local/bin/rffmpeg /usr/local/bin/ffmpeg \
    && ln -s /usr/local/bin/rffmpeg /usr/local/bin/ffprobe \
    && mkdir -p /etc/rffmpeg /var/lib/rffmpeg

# The official base pins JELLYFIN_FFMPEG=/usr/lib/jellyfin-ffmpeg/ffmpeg
# (env beats encoding.xml, so editing EncoderAppPath would silently do
# nothing). Repoint it at the rffmpeg shim; the real jellyfin-ffmpeg
# stays at /usr/lib/jellyfin-ffmpeg/* as rffmpeg's local fallback (the
# brain keeps its GPU slice precisely so hwaccel fallback works).
ENV JELLYFIN_FFMPEG=/usr/local/bin/ffmpeg

# Runtime configuration NOT baked here (ships as a ConfigMap in the
# rffmpeg-worker chart, keys validated against rffmpeg.yml.sample):
#   /etc/rffmpeg/rffmpeg.yml  — logfile must point at a WRITABLE path
#     (default /var/log/jellyfin/ does not exist in this image and
#     crashes rffmpeg); directories.persist -> /dev/shm; fallback
#     commands -> /usr/lib/jellyfin-ffmpeg/*.
#   RFFMPEG_POSTGRES_HOST/PORT/DB/USER/PASS env (pod-level) — switches
#     state to the central PostgreSQL (SQLite state on NFS is a lock-
#     contention trap). TMPDIR must point at worker-shared storage
#     (Jellyfin 10.10+ requirement; rffmpeg forwards no env).
