# creates the shared tool-versions bucket if it doesn't already exist.
# idempotent: gsutil ls succeeds (rc=0) when the bucket exists, otherwise we create it.
gcp_tools_bucket_create:
	gsutil ls -b $(GCP_TOOLS_BUCKET) >/dev/null 2>&1 || \
		gsutil mb -p $(GCP_PROJECT_ID) $(GCP_TOOLS_BUCKET)

# cloud-side target: executed inside the mdocker container on the dsub vm (or locally via PAR_TYPE=local).
# writes the snapshot to the par-mounted output dir, then publishes to the shared bucket.
# publishing overwrites the same key on re-runs (intentional); PAR_TYPE in the path
# keeps local vs dsub snapshots from colliding.
# to force a refresh at the same GCP_IMAGE_VER, delete $(GCP_TOOLS_DONE).
GCP_TOOLS_DONE?=$(GCP_TOOLS_DIR)/.done_tools_versions
$(GCP_TOOLS_DONE):
	$(call _start,$(GCP_TOOLS_DIR))
	echo "# image:    $(GCP_IMAGE_NAME)"                  >  $(GCP_TOOLS_FILE)
	echo "# version:  $(GCP_IMAGE_VER)"                   >> $(GCP_TOOLS_FILE)
	echo "# snapshot: $$(date -u +%Y-%m-%dT%H:%M:%SZ)"    >> $(GCP_TOOLS_FILE)
	echo "# host:     $$(uname -srm)"                     >> $(GCP_TOOLS_FILE)
	echo ""                                               >> $(GCP_TOOLS_FILE)
	bash $(GCP_CONTAINER_DIR)/tools_versions.sh            >> $(GCP_TOOLS_FILE)
	gsutil cp $(GCP_TOOLS_FILE) $(GCP_TOOLS_BUCKET_PATH)
	$(_end_touch)
mdocker_tools_versions_run: gcp_tools_bucket_create $(GCP_TOOLS_DONE)

# dispatcher: runs mdocker_tools_versions_run on a gcp vm (or locally with PAR_TYPE=local).
d_mdocker_tools_versions:
	mkdir -p $(GCP_TOOLS_DIR)
	$(MAKE) m=par par \
		PAR_WORK_DIR=$(GCP_TOOLS_DIR) \
		PAR_MODULE=gcp \
		PAR_NAME=mdocker_tools_versions \
		PAR_ODIR_VAR=GCP_TOOLS_DIR \
		PAR_TARGET=mdocker_tools_versions_run \
		PAR_PREEMTIBLE=0 \
		PAR_WAIT=T \
		PAR_MAKEFLAGS="$(PAR_MAKEOVERRIDES)"
