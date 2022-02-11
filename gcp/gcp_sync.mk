# upload local makeshift files to bucket
rsync:
	$(MAKE) gcp_mb GCP_MOUNT_BUCKET=$(GCP_MAKESHIFT_BUCKET)
	$(MAKE) gcp_mb GCP_MOUNT_BUCKET=$(GCP_MAKESHIFT_CONFIG_BUCKET)
	gsutil -m rsync -d $(MAKESHIFT_ROOT) $(GCP_MAKESHIFT_BUCKET)
	gsutil -m rsync -r -d $(MAKESHIFT_CONFIG) $(GCP_MAKESHIFT_CONFIG_BUCKET)
	gsutil -m rsync -r -d $(MAKESHIFT_ROOT)/makeshift-core $(GCP_MAKESHIFT_BUCKET)/makeshift-core
	$(foreach M,$(GCP_MAKESHIFT_MODULES), gsutil -m rsync -r -d $(MAKESHIFT_ROOT)/modules/$M $(GCP_MAKESHIFT_BUCKET)/modules/$M; $(ASSERT);) 
	$(foreach M,$(GCP_MAKESHIFT_EXTRA), gsutil -m rsync -r -d $(MAKESHIFT_ROOT)/$M $(GCP_MAKESHIFT_BUCKET)/$M; $(ASSERT);) 
