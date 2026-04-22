# mdocker-metagenomics-22.04 changelog

Newest-first. Each stanza covers the `GCP_IMAGE_VER` label in the heading. For deeper context see git history and the `details.txt` snapshots under `gs://${GCP_PROJECT_ID}-image-tool-versions/mdocker-metagenomics-22.04/vX.YY/{dsub,local}/`.

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
