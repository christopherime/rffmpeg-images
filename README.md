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

- worker: key-only root sshd (hardened drop-in), host keys regenerated
  per pod (rffmpeg uses `StrictHostKeyChecking=no`), NVIDIA JIT cache
  symlinked off NFS to `/nvcache` (mount an emptyDir there)
- brain: `python3-psycopg2` included so rffmpeg state can use the
  central PostgreSQL instead of SQLite (SQLite state on NFS hits lock
  contention under concurrent transcodes)
