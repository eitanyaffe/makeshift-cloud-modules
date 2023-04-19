
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

# upload local makeshift files to bucket
rsync:
	@echo Uploading code to buckets ...
	@$(MAKE) gcp_mb GCP_MOUNT_BUCKET=$(GCP_MAKESHIFT_BUCKET)
	@$(MAKE) gcp_mb GCP_MOUNT_BUCKET=$(GCP_MAKESHIFT_CONFIG_BUCKET)
	gsutil -q cp $(GCP_KEY_FILE) $(GCP_MAKESHIFT_BUCKET)/keys/makeshift.json
	gsutil -mq rsync -r -d $(MAKESHIFT_CONFIG) $(GCP_MAKESHIFT_CONFIG_BUCKET)
	gsutil -mq rsync -r -d $(MAKESHIFT_ROOT)/makeshift-core $(GCP_MAKESHIFT_BUCKET)/makeshift-core
	$(foreach M,$(GCP_MAKESHIFT_MODULES), gsutil -mq rsync -r -d $(MAKESHIFT_ROOT)/modules/$M $(GCP_MAKESHIFT_BUCKET)/modules/$M; $(ASSERT);) 
	$(foreach M,$(GCP_MAKESHIFT_EXTRA), gsutil -mq rsync -r -d $(MAKESHIFT_ROOT)/$M $(GCP_MAKESHIFT_BUCKET)/$M; $(ASSERT);)
	@echo Finished uploading code to buckets
	@echo "====================================================================================="
