# mdocker-metagenomics-22.04 changelog

Newest-first. Each stanza covers the `GCP_IMAGE_VER` label in the heading. For deeper context see git history and the `details.txt` snapshots under `gs://${GCP_PROJECT_ID}-image-tool-versions/mdocker-metagenomics-22.04/vX.YY/{dsub,local}/`.

## v1.09 — 2026-10-04 (mode: mode-3-reorg)

Label dsub's Batch VMs so billing reports can group by `job-name` and the
`ms-*` labels again, and reorganize the Dockerfile into topical sections.

Since the move from `google-cls-v2` to `google-batch`, dsub 0.5.4 puts its
labels (`job-name`, `job-id`, `user-id`, `task-id`, every `--label`) only on
`Job.labels`, which Batch applies to the job and its log entries, not to the
Compute Engine resources it creates. Only `AllocationPolicy.labels` reaches
VMs and disks, which is what billing sees. Verified on a v1.09 test job: the
VM carries `job-name`, `job-id`, `user-id`, `dsub-version` and
`ms-project-name` next to Batch's own labels.

### local patches
- New `dsub_labels_patch.py`: after `build_allocation_policy(...)` in
  `providers/google_batch.py`, adds `allocation_policy.labels = labels`. Pins
  `EXPECTED_DSUB_VER=0.5.4`, asserts exactly one call site and that `labels`
  is built before it; idempotent; syntax-checks before writing.
- Labels only appear on jobs submitted from a v1.09 container (the patch is in
  the submitting dsub), so the user's denv must run v1.09 too.

### pinned-tool changes
- sourmash/sendgrid step: `PIP_CONSTRAINT` → `PIP_BUILD_CONSTRAINT`. The reorg
  invalidated the cached `pip install --upgrade pip` layer, pulling pip 26,
  which no longer applies `PIP_CONSTRAINT` to isolated build envs; screed
  1.1.3 then failed on missing `pkg_resources`.
- Dropped the duplicate unversioned `prodigal` apt install (the pinned
  `prodigal=1:2.6.*` in the HMMER block remains; resolves to 1:2.6.3-5).

### structural changes
- One merged system-packages stage (base utils, compilers/autotools, -dev libs
  for R/MOB-suite/plotly/ggtree, small apt bio tools: bedtools, aragorn,
  mafft, clustalo), replacing ~15 scattered apt installs.
- Section order: system → docker → venv → gcloud/gcsfuse/dsub (both patches)
  → R + all R packages → perl modules → java/nextflow → reads (sra-tools,
  edirect, fastp, seqtk, bwa/samtools, minimap2) → assemblers → taxonomic
  profiling → gene search/annotation → GTDB-Tk binaries → python packages →
  StrainFinder (py2) → document rendering → shell conveniences → identity.
- Python venv installs keep their prior relative order (comment added);
  macsyfinder's unpinned numpy/pandas force-reinstall stays last.
- All `APPENDIX-ADDED` marks resolved. Aliases and `glg` moved to the end so
  editing `glg` no longer invalidates downstream layers.

### tools_versions.sh
- New `dsub-vm-labels` patch line. The v1.09 snapshot predates it reaching
  the worker (line absent); patch state was verified via the test VM instead.
- Fixed `streme` / `fimo` (bare `5.5.9` output) and `infernal` (`INFERNAL`
  uppercase) grep patterns; v1.09 shows these as ERROR though rc=0.

### operational notes
- DB rebuild required: no.
- Denv restart required: yes (also required for the labels to apply).
- numpy 2.2.6 / pandas 2.3.3, unchanged vs the v1.05 snapshot (no v1.06–v1.08
  snapshots in the bucket).
- Known drift in unpinned components: skani 0.3.1 → 0.3.2, edirect 25.3 →
  26.3, google-cloud-batch → 0.22.0 (pulled by dsub), plus routine apt/CRAN.
- The v1.08 registry tag was overwritten by an interim build of this image.
- Config bumps: `modules/cloud/gcp/gcp_int.mk` → `GCP_IMAGE_VER?=v1.09`.

## v1.08 — 2026-09-07 (mode: mode-2-add)

Patch dsub's continuous log-uploader so a failed log upload can no longer mark
a healthy Batch task FAILED. On v1.07 a 6-hour GTDB batch task finished its
work and delocalized every output, yet Batch reported the task FAILED; `dsub
--wait` propagated that to the coordinator, which then deleted the job's
healthy sibling tasks and retried the whole thing.

Root cause is in dsub's `_LOG_CP` bash (`providers/google_batch.py`), which
launches three `gcloud storage cp` calls in parallel and `wait`s on each under
`set -o errexit`. Google documents that parallel gcloud invocation is
unsupported — the processes share `~/.config/gcloud/access_tokens.db` and race
on its sqlite lock (`WARNING: Could not store access token in cache: database
is locked`, then `ERROR: gcloud crashed (OperationalError)`). dsub's 4-attempt
retry exhausted itself on the hot lock, `gcloud_cp` hit its `exit 1`, and since
the uploader is a background runnable that dsub does not mark
`ignore_exit_status`, Batch failed the whole task.

This is a v1.07 regression in the sense that it was unreachable before: dsub
0.5.1 did these copies with `gsutil`, which does not use gcloud's sqlite token
cache. The 0.5.3 `gsutil` → `gcloud storage` migration made dsub's pre-existing
parallelism unsafe. The `294.0.0-slim` → `583.0.0-slim` wrapper bump is not the
cause and was not optional — `gcloud storage` does not exist in 294.0.0.

### local patches
- New `dsub_logging_patch.py`, applied to the installed dsub after
  `pip install`. Serializes the three log copies and wraps each as
  `( gcloud_cp ... ) || true`. The subshell is required, not cosmetic: dsub's
  `gcloud_cp` ends in `exit 1`, which without `&` to contain it would kill the
  logging loop outright, and `|| true` does not stop `exit`.
- The script pins `EXPECTED_DSUB_VER=0.5.4` and asserts it finds exactly
  3 launches / 3 pid vars / 3 waits, so a dsub bump fails the build instead of
  silently shipping an unpatched image. It is idempotent and syntax-checks the
  result before writing.

### tools_versions.sh
- New `# local patches` section reporting `dsub-serial-log-upload`
  (`applied (3 log copies serialized)` vs `MISSING (found N/3)`) and the
  effective `dsub-cloud-sdk-image` tag, so `details.txt` shows patch state.

### operational notes
- DB rebuild required: no.
- Denv restart required: yes, to pick up v1.08.
- Rebuild cost: the `COPY dsub_logging_patch.py` sits just after the dsub
  install, so everything below reuses cache and everything above it rebuilds.
- Config bumps: `modules/cloud/gcp/gcp_int.mk` → `GCP_IMAGE_VER?=v1.08`.
- Verify after build: `mdocker_tools_versions` should show
  `patch  dsub-serial-log-upload  applied (3 log copies serialized)`.

## v1.07 — 2026-09-01 (mode: mode-3-upgrade)

Unblock dsub: bump dsub v0.5.1 → v0.5.4 and patch its hardcoded cloud-sdk
wrapper image pin from a Google-pruned tag to a currently-published one. Every
`dsub`-launched Batch task on v1.06 was failing at wrapper image pull with
`RUNNING → FAILED exit 1` and no log upload, because dsub 0.5.1's
`google_utils.py:CLOUD_SDK_IMAGE` pins
`gcr.io/google.com/cloudsdktool/cloud-sdk:294.0.0-slim`, which Google removed
from gcr.io. v0.5.4's own pin (`499.0.0-slim`) is also already pruned, hence
the sed to `583.0.0-slim` (the current published tag).

### pinned-tool changes
- dsub (git clone): `v0.5.1` → `v0.5.4`. Completes the `gsutil` →
  `gcloud storage` migration in dsub's own wrapper bash (log-upload,
  input-localize, output-delocalize runnables that Batch runs in the cloud-sdk
  image). Does not affect user `gsutil` calls in `modules/cloud/gcp/*.mk`.
- cloud-sdk wrapper image (patched, not a Dockerfile pin): `294.0.0-slim` →
  `583.0.0-slim`. This is Google's public helper image pulled by Batch on the
  cloud VM; not baked into mdocker. Bump the sed's RHS when Google prunes
  583.0.0 too — check with
  `gcloud container images list-tags gcr.io/google.com/cloudsdktool/cloud-sdk`.

### operational notes
- DB rebuild required: no.
- Denv restart required: yes, to pick up v1.07.
- Rebuild cost: one changed layer at the `dsub` install; everything below the
  dsub layer reuses cache, everything above rebuilds from that point.
- Config bumps: `modules/cloud/gcp/gcp_int.mk` → `GCP_IMAGE_VER?=v1.07`.

## v1.03 — 2026-04-22 (mode: mode-2-add)

Added the `qrcode` R package. No pinned-tool version changes, no reorg.

### R packages
- Added `qrcode` (CRAN). Used by `fig.start`/`fig.end` in `makeshift-core/utils.r` to stamp a small vector QR of the output path in the bottom-left corner of every PDF/PNG. Payload is `src: <full path>` so phone QR readers offer a clean copy/paste.

### tools_versions.sh
- Added `qrcode` to the R-package loop so its version is recorded in `details.txt`.

### operational notes
- DB rebuild required: no.
- Denv restart required: yes, to pick up v1.03.
- Rebuild cost: one new cached R layer at the tail; all earlier layers reused cache.

## v1.02 — 2026-04-20 (mode: mode-3-upgrade)

Batch upgrade of seven pinned tools; no reorg, no Ubuntu bump.

### pinned-tool changes
- barrnap: commit `acf3198` (0.9+4) → `v1.10.6` (tag); switched from `git checkout <sha>` to `--branch v1.10.6 --single-branch`
- diamond: `v2.0.15` → `v2.1.24` — .dmnd DB format changed; existing `.dmnd` indexes must be rebuilt
- fastANI: `v1.33` → `v1.34` — note: the v1.34 binary self-reports `version 1.33` (upstream did not bump the embedded string); the zipball is genuinely the v1.34 release
- myloasm: `v0.4.0` → `v0.5.1`
- dsub (pip + repo): `v0.5.0` → `v0.5.1`
- gcsfuse: `0.41.12` → `3.2.6` — dropped the stale "0.42.1 fails to mount" comment (that issue was from 2022)
- sra-tools: `3.2.0` → `3.4.1` — NCBI also renamed the cloud build from `centos_linux64-cloud` to `alma_linux64-cloud` at 3.3

### attempted but not applied
- metaMDBG `1.2 → 1.3.1`: upstream 1.3.x fails to link under gcc-11 (undefined references to `ToBasespace2::CreateBaseContigsFunctor::CoverageRegion::low` / `::normal` — class-static members declared but not defined). 1.3 tag and master HEAD carry the same defect. Held at 1.2; Dockerfile has an inline note. Revisit once upstream ships a fix or we decide to carry a source patch.
- minimap2 `2.28 → 2.30`: held at 2.28 per user call (deferred to a later session).
- checkm-genome `1.2.4 → 1.2.5`: held at 1.2.4 per user call (deferred to a later session).

### incidental drift (verified against `v1.02/dsub/details.txt`)
- `google-cloud-batch` (pip): `0.17.20` → `0.21.0`. The Dockerfile still pins `==0.17.20` in an earlier layer, but `pip install .` for dsub v0.5.1 pulled it forward to satisfy dsub's declared dep. The standalone pin is now stale/misleading — candidate for cleanup in a later pass.
- `tools_versions.sh` now queries `r-base-core` instead of the phantom `r-base-dev` (which always reported `MISSING`). Snapshot-only fix, not a container change.

### operational notes
- DB rebuild required: yes, `.dmnd` diamond databases (any built against 2.0.x must be rebuilt with 2.1.x).
- Denv restart required: yes, to pick up v1.02 — existing long-running denv sessions remain on v1.01 until restarted.
- Known drift in unpinned components: none notable (baseline v1.01 was ~30 min old at the start of this session).

## v1.01 — 2026-04-20 (baseline)

First snapshot tracked in this CHANGELOG. State at v1.01 is the authoritative starting point for all future diffs; see `gs://.../v1.01/dsub/details.txt`.

## v1.00 — earlier baseline

Historical. State captured in `gs://.../v1.00/{dsub,local}/details.txt`.
