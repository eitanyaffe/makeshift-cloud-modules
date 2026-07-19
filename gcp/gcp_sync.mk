
bucket_summary:
	$(call _assert,GCP_MAKESHIFT_BUCKET  GCP_MAKESHIFT_CONFIG_BUCKET GCP_DSUB_ODIR_BUCKET BINARY_BUCKET)
	@echo "====================================================================================="
	@echo "core buckets:"
	@echo "GCP_MAKESHIFT_BUCKET=$(GCP_MAKESHIFT_BUCKET) [code bucket]"
	@echo "GCP_MAKESHIFT_CONFIG_BUCKET=$(GCP_MAKESHIFT_CONFIG_BUCKET) [configuration bucket]"
	@echo "GCP_DSUB_ODIR_BUCKET=$(GCP_DSUB_ODIR_BUCKET) [output bucket]"
	@echo "BINARY_BUCKET=$(BINARY_BUCKET) [compiled binaries bucket]"
	@echo "====================================================================================="
	@$(MAKE) info_buckets --no-print-directory
	@echo "====================================================================================="

# legacy: sequential per-module gsutil rsync (kept temporarily for comparison; slated for removal)
rsync_old:
	@echo Uploading code to buckets ...
	@$(MAKE) gcp_mb GCP_MOUNT_BUCKET=$(GCP_MAKESHIFT_BUCKET)
	@$(MAKE) gcp_mb GCP_MOUNT_BUCKET=$(GCP_MAKESHIFT_CONFIG_BUCKET)
	gsutil -q cp $(GCP_KEY_FILE) $(GCP_MAKESHIFT_BUCKET)/keys/makeshift.json
	if [ -f /keys/sendgrid.key ]; then \
		echo Uploading SendGrid key ...; \
		gsutil -q cp /keys/sendgrid.key $(GCP_MAKESHIFT_BUCKET)/keys/sendgrid.key; \
	fi
	gsutil -mq rsync -r -d $(MAKESHIFT_CONFIG) $(GCP_MAKESHIFT_CONFIG_BUCKET)
	gsutil -mq rsync -r -d $(MAKESHIFT_ROOT)/makeshift-core $(GCP_MAKESHIFT_BUCKET)/makeshift-core
	$(foreach M,$(GCP_MAKESHIFT_MODULES), gsutil -mq rsync -r -d $(MAKESHIFT_ROOT)/modules/$M $(GCP_MAKESHIFT_BUCKET)/modules/$M; $(ASSERT);) 
	$(foreach M,$(GCP_MAKESHIFT_EXTRA), gsutil -mq rsync -r -d $(MAKESHIFT_ROOT)/$M $(GCP_MAKESHIFT_BUCKET)/$M; $(ASSERT);)
	@echo Finished uploading code to buckets
	@echo "====================================================================================="

# persistent local staging dir for rsync; per pipeline+config to avoid cross-run collisions
GCP_SYNC_STAGE?=/tmp/makeshift-sync-$(PIPELINE_NAME)-$(c)

# upload local makeshift files to bucket: stage code locally with rsync -a, then one gsutil rsync
rsync:
	@echo Uploading code to buckets ...
	@$(MAKE) gcp_mb GCP_MOUNT_BUCKET=$(GCP_MAKESHIFT_BUCKET)
	@$(MAKE) gcp_mb GCP_MOUNT_BUCKET=$(GCP_MAKESHIFT_CONFIG_BUCKET)
	gsutil -mq rsync -r -d $(MAKESHIFT_CONFIG) $(GCP_MAKESHIFT_CONFIG_BUCKET)
	@echo Staging code tree to $(GCP_SYNC_STAGE) ...
	rm -rf $(GCP_SYNC_STAGE)/modules $(GCP_SYNC_STAGE)/keys
	mkdir -p $(GCP_SYNC_STAGE)/keys
	cp $(GCP_KEY_FILE) $(GCP_SYNC_STAGE)/keys/makeshift.json
	if [ -f /keys/sendgrid.key ]; then cp /keys/sendgrid.key $(GCP_SYNC_STAGE)/keys/sendgrid.key; fi
	cd $(MAKESHIFT_ROOT) && rsync -a --delete --relative \
		makeshift-core \
		$(addprefix modules/,$(GCP_MAKESHIFT_MODULES)) \
		$(GCP_MAKESHIFT_EXTRA) \
		$(GCP_SYNC_STAGE)/
	@echo Uploading staged tree to $(GCP_MAKESHIFT_BUCKET) ...
	gsutil -mq rsync -r -d $(GCP_SYNC_STAGE) $(GCP_MAKESHIFT_BUCKET)
	@echo Finished uploading code to buckets
	@echo "====================================================================================="
