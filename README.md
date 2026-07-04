# rffmpeg-images

Container images for **distributed Jellyfin transcoding** on the GXF
cluster (rffmpeg brain + ffmpeg workers across both GPU nodes).

| Image | Base | Purpose |
| ----- | ---- | ------- |
| `ghcr.io/geekxflood/rffmpeg-worker:<jellyfin-version>` | `jellyfin/jellyfin` | sshd + the exact matching `jellyfin-ffmpeg`; receives transcode jobs over SSH |
| `ghcr.io/geekxflood/jellyfin-pgsql-rffmpeg:<pgsql-tag>` | `ghcr.io/jpvenson/jellyfin.pgsql` | the Jellyfin "brain" with the [rffmpeg](https://github.com/joshuaboniface/rffmpeg) shim symlinked as `ffmpeg`/`ffprobe` (`JELLYFIN_FFMPEG` repointed) |

## Version lockstep rule

Jellyfin emits ffmpeg arguments for its bundled `jellyfin-ffmpeg` —
**worker and brain tags must always carry the same Jellyfin version**
(bump `JELLYFIN_VERSION` and `PGSQL_TAG` together in
`.github/workflows/build.yml`). A version-skewed worker fails
mid-transcode on CUDA filter/segment options.

## Deployment

Consumed by the `rffmpeg-worker` chart (geekxflood/helm-charts) and the
`jellyfin-new` ArgoCD Application (geekxflood/applicationset). Cluster
documentation: `wiki/docs/applications/media/` in the applicationset
repo.

Operational notes baked into the images:

- worker: key-only root sshd (hardened drop-in) **plus** upstream's
  `limited-wrapper.py` ForceCommand allowlist — the Secret-mounted
  `authorized_keys` entry must carry
  `command="/usr/local/bin/limited-wrapper.py",restrict ` before the
  key material, so a leaked key can only run ffmpeg/ffprobe; host keys
  regenerated per pod (rffmpeg uses `StrictHostKeyChecking=no`); NVIDIA
  JIT cache symlinked off NFS to `/nvcache` (mount an emptyDir there)
- brain: rffmpeg pinned at commit `f54ac843` (master line; the file is
  `rffmpeg`, extensionless — verified 2026-07-04); `python3-psycopg2`
  included because setting any `RFFMPEG_POSTGRES_*` env switches state
  to PostgreSQL with an **unguarded** import (missing module =
  ImportError on every transcode); symlinks are extensionless and NOT
  under a path containing "rffmpeg" (argv[0] substring dispatch);
  `JELLYFIN_FFMPEG` re-pointed at the shim (env beats `encoding.xml`)

Why custom images (verified 2026-07-04, decision on record): NO usable
alternative exists — `ghcr.io/aleksasiriski/rffmpeg-worker` is deleted
from GHCR (pull fails), `cplemaster/jellyfin-rffmpeg-worker` is an
unreproducible `docker commit` frozen at ffmpeg 7.1.1 (need 7.1.4),
`djsitte/rffmpeg-worker` is Alpine/musl (NVIDIA glibc libs won't load),
Shadowghost/bitwrk brain lags at Jellyfin 10.11.7 with a dead repo, and
the LinuxServer mod would force a config-PVC layout migration + runtime
mod downloads while still lacking psycopg2.
