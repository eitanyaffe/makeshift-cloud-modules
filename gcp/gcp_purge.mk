# remove older version from directory
P_PURGE_DIR?=NA
P_CURRENT_VER?=NA

# by default wait 10 seconds to allow to cancel
P_PURGE_SLEEP?=10s

# versions usually start with v (opposed to info dir which we wish to keep)
P_PREFIX?=v

ifneq ($(P_PURGE_DIR),NA)
P_OLD_VERS?=$(shell ls $(P_PURGE_DIR) | grep -v $(P_CURRENT_VER) | grep '^$(P_PREFIX)')
else
P_OLD_VERS?=
endif

P_BUCKET_DIR?=$(subst $(GCP_DSUB_ODIR_BUCKET_BASE)/,,$(P_PURGE_DIR))
purge_old_versions:
ifneq ($(P_OLD_VERS),)
	@echo ==========================================================================================
	@echo "Current version directory (not removed): $(P_PURGE_DIR)/$(P_CURRENT_VER)"
	@echo Will remove previous versions in $(P_PURGE_SLEEP): $(P_OLD_VERS)
	@sleep $(P_PURGE_SLEEP)
	$(foreach t,$(P_OLD_VERS),\
	gsutil -mq rm -rf $(GCP_DSUB_ODIR_BUCKET)/$(P_BUCKET_DIR)/$t; )
	@echo done purging $(P_PURGE_DIR)
	@echo ==========================================================================================
endif
