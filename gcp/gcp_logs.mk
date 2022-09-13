
# explicit download function
gcp_logs_download_path:
	$(_R) $(_md)/R/gcp_logs.r download.log.root \
		log.path=$(GCP_LOG_PATH) \
		recursive=$(GCP_LOG_RECURSIVE) \
		out.bucket=$(GCP_DSUB_ODIR_BUCKET) \
		odir=$(GCP_LOG_RUN_DIR)


# explicit download function
gcp_logs_download_key:
	$(_R) $(_md)/R/gcp_logs.r download.log.by.key \
		ifn=$(GCP_LOG_RUN_FILE) \
		recursive=$(GCP_LOG_RECURSIVE) \
		out.bucket=$(GCP_DSUB_ODIR_BUCKET) \
		odir=$(GCP_LOG_RUN_DIR)
