###############################################################################################
# create buckets
###############################################################################################

gcp_mb:
	@gsutil ls $(GCP_MOUNT_BUCKET) > /dev/null 2>&1; if [ $$? -eq 0 ]; then \
	echo "Bucket $(GCP_MOUNT_BUCKET) already exists, skipping" \
	; else \
	gsutil mb -p $(GCP_PROJECT_ID) -l $(GCP_LOCATION) -c $(GCP_CLASS) $(GCP_MOUNT_BUCKET) \
	; fi

make_buckets:
	$(MAKE) class_loop class=gmount t=gcp_mb

# make single bucket
make_bucket:
	$(MAKE) class_step class=gmount instance=$i t=gcp_mb

###############################################################################################
# destroy buckets
###############################################################################################

gcp_rb:
	gsutil ls $(GCP_MOUNT_BUCKET) > /dev/null 2>&1; if [ $$? -eq 0 ]; then \
	gsutil -mq rm -f -R $(GCP_MOUNT_BUCKET)/*; gsutil rb -f $(GCP_MOUNT_BUCKET) \
	; else \
	echo "Bucket $(GCP_MOUNT_BUCKET) does not exists, skipping" \
	; fi

destroy_bucket:
	$(MAKE) class_step class=gmount instance=$i t=gcp_rb

destroy_buckets:
	$(MAKE) class_loop class=gmount t=gcp_rb

###############################################################################################
# mount buckets locally
###############################################################################################

gcp_mount:
	@gsutil ls $(GCP_MOUNT_BUCKET) > /dev/null 2>&1; if [ $$? -eq 0 ]; then \
	mkdir -p $(GCP_MOUNT_VAR) && \
	gcsfuse $(GCP_GCSFUSE_EXTRA) \
		-o allow_other \
		--file-mode $(GCP_MOUNT_FILE_MODE) \
		--key-file $(GCP_KEY_FILE) \
		$(GCP_MOUNT_BUCKET_SHORT) \
		$(GCP_MOUNT_VAR) \
	; else \
	echo "Error mounting $(GCP_MOUNT_BUCKET), skipping" \
	; fi

# create and mount
gcp_create_mount: gcp_mb gcp_mount

mount_bucket:
	$(MAKE) class_step class=gmount instance=$i t=gcp_mount

create_mount_bucket:
	$(MAKE) class_step class=gmount instance=$i t=gcp_create_mount

mount_buckets:
	$(MAKE) class_loop class=gmount t=gcp_mount

###############################################################################################
# mount buckets locally under home, useful to view results
###############################################################################################

mount_bucket_home:
	mkdir -p $(GCP_LOCAL_MOUNT_PATH)/$(GCP_MOUNT_VAR)
	gcsfuse $(GCP_GCSFUSE_EXTRA) \
		$(GCP_MOUNT_BUCKET_SHORT) \
		$(GCP_LOCAL_MOUNT_PATH)/$(GCP_MOUNT_VAR)

mount_buckets_home:
	$(MAKE) class_loop class=gmount t=mount_bucket_home

###############################################################################################
# remove files
###############################################################################################

gcp_remove:
	$(_R) $(_md)/R/gcp_utils.r remove.paths \
	       base.mount=$(GCP_DSUB_ODIR_BUCKET_BASE) \
	       out.bucket=$(GCP_DSUB_ODIR_BUCKET) \
	       paths=$(GCP_REMOVE_PATHS)

gcp_remove_find:
	$(_R) $(_md)/R/gcp_utils.r remove.find \
	       base.mount=$(GCP_DSUB_ODIR_BUCKET_BASE) \
	       out.bucket=$(GCP_DSUB_ODIR_BUCKET) \
	       base.dir=$(GCP_REMOVE_DIR) \
	       name.pattern=$(GCP_REMOVE_NAME_PATTERN)

# remove path from output bucket
qdel:
	@bash $(_md)/sh/yes_no.sh $(GCP_DSUB_ODIR_BUCKET)/$X
	gsutil -mq rm -rf $(GCP_DSUB_ODIR_BUCKET)/$X

###############################################################################################
# bucket disk usage
###############################################################################################

# query list of buckets
gcp_du_all:
	$(_R) $(_md)/R/gcp_du.r du \
		ifn=$(GCP_DU_DEPTH_TABLE) \
		project=$(GCP_PROJECT_ID) \
		check.all=$(GCP_DU_CHECK_ALL)

# query main project bucket
gcp_du_project:
	$(_R) $(_md)/R/gcp_du.r du.bucket \
		bucket=$(GCP_DSUB_ODIR_BUCKET) \
		project=$(GCP_PROJECT_ID) \
		unit=$(GCP_DU_TOTAL_UNIT) \
		depth=$(GCP_DU_DEPTH)

# print total project usage
gcp_du_total:
	$(_R) $(_md)/R/gcp_du.r total.project.usage \
		project=$(GCP_PROJECT_ID) \
		unit=$(GCP_DU_TOTAL_UNIT)
