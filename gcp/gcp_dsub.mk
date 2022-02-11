
# TBD: implement
# 1. support single output directory or file 
# 2. organize multiple mounts 
# 3. set up environment variables

# base output directory
# GCP_DSUB_ODIR_BUCKET_BASE: base directory where output bucket is mounted
# GCP_DSUB_ODIR_VAR: variable name of output directory

# output directory 
GCP_DSUB_ODIR=$($(GCP_DSUB_ODIR_VAR))

DSUB_WORK_DIR?=$(GCP_DSUB_ODIR)/dsub/$(GCP_DSUB_NAME)

DSUB_TASK_ITEM_ODIR=$(foreach X,$(GCP_DSUB_TASK_ITEM_VALS),$(call reval,$(GCP_DSUB_TASK_ODIR_VAR),$(GCP_DSUB_TASK_ITEM_VAR)=$X))

#DSUB_TASK_ITEM_EXIST=$(call _to_bucket,$(foreach X,\
#$(GCP_DSUB_TASK_ITEM_VALS),$(call reval,$(shell $(MAKE) -q $(GCP_DSUB_TARGET); echo $?)),$(GCP_DSUB_TASK_ITEM_VAR)=$X)))

dsub:
	$(_R) $(_md)/R/dsub_all.r dsub.ms \
	       job.work.dir=$(GCP_WORK_DIR) \
	       module=$(GCP_DSUB_MODULE) \
	       base.mount=$(GCP_DSUB_ODIR_BUCKET_BASE) \
	       out.bucket=$(GCP_DSUB_ODIR_BUCKET) \
	       out.var=$(GCP_DSUB_ODIR_VAR) \
	       out.dir=$(GCP_DSUB_ODIR) \
	       ms.root=$(GCP_MAKESHIFT_BUCKET) \
	       ms.cfg=$(GCP_MAKESHIFT_CONFIG_BUCKET) \
	       wdir=$(GCP_PIPELINE_RELATIVE_DIR) \
	       provider=$(GCP_DSUB_PROVIDER) \
	       project=$(GCP_PROJECT_ID) \
	       zones=$(GCP_ZONE) \
	       region=$(GCP_REGION) \
	       image=$(GCP_GCR_IMAGE_PATH) \
	       machine.spec.style=$(GCP_DSUB_SPEC_STYLE) \
	       machine.type=$(GCP_DSUB_MACHINE) \
	       machine.ram.gb=$(GCP_DSUB_RAM_GB) \
	       machine.boot.gb=$(GCP_DSUB_BOOT_GB) \
	       machine.disk.type=$(GCP_DSUB_DISK_TYPE) \
	       machine.disk.gb=$(GCP_DSUB_DISK_GB) \
	       machine.cpu.count=$(GCP_DSUB_CPU_COUNT) \
	       target=$(GCP_DSUB_TARGET) \
	       name=$(GCP_DSUB_NAME) \
	       project.name=$(GCP_MS_PROJECT_NAME) \
	       credentials.file=$(GCP_KEY_FILE) \
	       mount.buckets=$(GCP_MOUNT_BUCKETS) \
	       mount.bucket.vars=$(GCP_MOUNT_VARS) \
	       preemtible.count=$(GCP_DSUB_PREEMTIBLE) \
	       non.preemtible.retry.count=$(PAR_NON_PREEMTIBLE_RETRIES) \
	       log.interval=$(GCP_DSUB_LOG_INTERVAL) \
	       dry=$(DRY) \
	       wait=$(GCP_DSUB_WAIT) \
	       drop.params=$(GCP_DSUB_DROP_PARAMS) \
	       ms.level=$(MS_LEVEL) \
	       job.id=$(PAR_JOB_ID) \
	       download.intermediates=$(GCP_DSUB_DOWNLOAD_INTERMEDIATES) \
	       upload.intermediates=$(GCP_DSUB_UPLOAD_INTERMEDIATES) \
	       email=$(PAR_NOTIFY_EMAIL) \
	       max.report.level=$(PAR_NOTIFY_MAX_LEVEL) \
	       send.email.flag=$(PAR_EMAIL) \
	       sendgrid.key=$(PAR_SENDGRID_API_KEY) \
	       params="DUMMY~1 $(subst =,~,$(GCP_DSUB_MAKEFLAGS))"

# multiple tasks over single variable
dsub_tasks:
	$(_R) $(_md)/R/dsub_all.r dsub.ms.tasks.batch \
	       job.work.dir=$(GCP_WORK_DIR) \
	       module=$(GCP_DSUB_MODULE) \
	       base.mount=$(GCP_DSUB_ODIR_BUCKET_BASE) \
	       out.bucket=$(GCP_DSUB_ODIR_BUCKET) \
	       ms.root=$(GCP_MAKESHIFT_BUCKET) \
	       ms.cfg=$(GCP_MAKESHIFT_CONFIG_BUCKET) \
	       wdir=$(GCP_PIPELINE_RELATIVE_DIR) \
	       provider=$(GCP_DSUB_PROVIDER) \
	       project=$(GCP_PROJECT_ID) \
	       zones=$(GCP_ZONE) \
	       region=$(GCP_REGION) \
	       image=$(GCP_GCR_IMAGE_PATH) \
	       machine.spec.style=$(GCP_DSUB_SPEC_STYLE) \
	       machine.type=$(GCP_DSUB_MACHINE) \
	       machine.ram.gb=$(GCP_DSUB_RAM_GB) \
	       machine.boot.gb=$(GCP_DSUB_BOOT_GB) \
	       machine.disk.type=$(GCP_DSUB_DISK_TYPE) \
	       machine.disk.gb=$(GCP_DSUB_DISK_GB) \
	       machine.cpu.count=$(GCP_DSUB_CPU_COUNT) \
	       target=$(GCP_DSUB_TARGET) \
	       name=$(GCP_DSUB_NAME) \
	       project.name=$(GCP_MS_PROJECT_NAME) \
	       credentials.file=$(GCP_KEY_FILE) \
	       mount.buckets=$(GCP_MOUNT_BUCKETS) \
	       mount.bucket.vars=$(GCP_MOUNT_VARS) \
	       task.odir.var=$(GCP_DSUB_TASK_ODIR_VAR) \
	       task.odir.vals=$(DSUB_TASK_ITEM_ODIR) \
	       task.item.var=$(GCP_DSUB_TASK_ITEM_VAR) \
	       task.item.vals="$(GCP_DSUB_TASK_ITEM_VALS)" \
	       batch.size=$(GCP_BATCH_SIZE) \
	       preemtible.count=$(GCP_DSUB_PREEMTIBLE) \
	       non.preemtible.retry.count=$(PAR_NON_PREEMTIBLE_RETRIES) \
	       dry=$(DRY) \
	       wait=$(GCP_DSUB_WAIT) \
	       log.interval=$(GCP_DSUB_LOG_INTERVAL) \
	       drop.params=$(GCP_DSUB_DROP_PARAMS) \
	       ms.level=$(MS_LEVEL) \
	       job.id=$(PAR_JOB_ID) \
	       download.intermediates=$(GCP_DSUB_DOWNLOAD_INTERMEDIATES) \
	       upload.intermediates=$(GCP_DSUB_UPLOAD_INTERMEDIATES) \
	       email=$(PAR_NOTIFY_EMAIL) \
	       max.report.level=$(PAR_NOTIFY_MAX_LEVEL) \
	       send.email.flag=$(PAR_EMAIL) \
	       sendgrid.key=$(PAR_SENDGRID_API_KEY) \
	       params="DUMMY~1 $(subst =,~,$(GCP_DSUB_MAKEFLAGS))"

# multiple tasks using table
dsub_tasks_complex:
	$(_R) $(_md)/R/dsub_all.r dsub.ms.complex.batch \
	       job.work.dir=$(GCP_WORK_DIR) \
	       module=$(GCP_DSUB_MODULE) \
	       base.mount=$(GCP_DSUB_ODIR_BUCKET_BASE) \
	       out.bucket=$(GCP_DSUB_ODIR_BUCKET) \
	       ms.root=$(GCP_MAKESHIFT_BUCKET) \
	       ms.cfg=$(GCP_MAKESHIFT_CONFIG_BUCKET) \
	       wdir=$(GCP_PIPELINE_RELATIVE_DIR) \
	       provider=$(GCP_DSUB_PROVIDER) \
	       project=$(GCP_PROJECT_ID) \
	       zones=$(GCP_ZONE) \
	       region=$(GCP_REGION) \
	       image=$(GCP_GCR_IMAGE_PATH) \
	       machine.spec.style=$(GCP_DSUB_SPEC_STYLE) \
	       machine.type=$(GCP_DSUB_MACHINE) \
	       machine.ram.gb=$(GCP_DSUB_RAM_GB) \
	       machine.boot.gb=$(GCP_DSUB_BOOT_GB) \
	       machine.disk.type=$(GCP_DSUB_DISK_TYPE) \
	       machine.disk.gb=$(GCP_DSUB_DISK_GB) \
	       machine.cpu.count=$(GCP_DSUB_CPU_COUNT) \
	       target=$(GCP_DSUB_TARGET) \
	       name=$(GCP_DSUB_NAME) \
	       project.name=$(GCP_MS_PROJECT_NAME) \
	       credentials.file=$(GCP_KEY_FILE) \
	       mount.buckets=$(GCP_MOUNT_BUCKETS) \
	       mount.bucket.vars=$(GCP_MOUNT_VARS) \
	       task.input.table=$(GCP_DSUB_TASK_ITEM_TABLE) \
	       task.item.var=$(GCP_DSUB_TASK_ITEM_VAR) \
	       task.odir.var=$(GCP_DSUB_TASK_ODIR_VAR) \
	       task.odir.vals=$(DSUB_TASK_ITEM_ODIR) \
	       batch.size=$(GCP_BATCH_SIZE) \
	       preemtible.count=$(GCP_DSUB_PREEMTIBLE) \
	       non.preemtible.retry.count=$(PAR_NON_PREEMTIBLE_RETRIES) \
	       dry=$(DRY) \
	       wait=$(GCP_DSUB_WAIT) \
	       log.interval=$(GCP_DSUB_LOG_INTERVAL) \
	       drop.params=$(GCP_DSUB_DROP_PARAMS) \
	       ms.level=$(MS_LEVEL) \
	       job.id=$(PAR_JOB_ID) \
	       download.intermediates=$(GCP_DSUB_DOWNLOAD_INTERMEDIATES) \
	       upload.intermediates=$(GCP_DSUB_UPLOAD_INTERMEDIATES) \
	       email=$(PAR_NOTIFY_EMAIL) \
	       max.report.level=$(PAR_NOTIFY_MAX_LEVEL) \
	       send.email.flag=$(PAR_EMAIL) \
	       sendgrid.key=$(PAR_SENDGRID_API_KEY) \
	       params="DUMMY~1 $(subst =,~,$(GCP_DSUB_MAKEFLAGS))"

# single direct call without makeshift 
dsub_direct:
	$(_R) $(_md)/R/dsub_all.r dsub.direct \
	       job.work.dir=$(GCP_WORK_DIR) \
	       base.mount=$(GCP_DSUB_ODIR_BUCKET_BASE) \
	       out.bucket=$(GCP_DSUB_ODIR_BUCKET) \
	       provider=$(GCP_DSUB_PROVIDER) \
	       project=$(GCP_PROJECT_ID) \
	       zones=$(GCP_ZONE) \
	       region=$(GCP_REGION) \
	       image=$(GCP_GCR_IMAGE_PATH) \
	       machine.spec.style=$(GCP_DSUB_SPEC_STYLE) \
	       machine.type=$(GCP_DSUB_MACHINE) \
	       machine.ram.gb=$(GCP_DSUB_RAM_GB) \
	       machine.boot.gb=$(GCP_DSUB_BOOT_GB) \
	       machine.disk.type=$(GCP_DSUB_DISK_TYPE) \
	       machine.disk.gb=$(GCP_DSUB_DISK_GB) \
	       machine.cpu.count=$(GCP_DSUB_CPU_COUNT) \
	       name=$(GCP_DSUB_NAME) \
	       project.name=$(GCP_MS_PROJECT_NAME) \
	       credentials.file=$(GCP_KEY_FILE) \
	       preemtible.count=$(GCP_DSUB_PREEMTIBLE) \
	       non.preemtible.retry.count=$(PAR_NON_PREEMTIBLE_RETRIES) \
	       dry=$(DRY) \
	       wait=$(GCP_DSUB_WAIT) \
	       log.interval=$(GCP_DSUB_LOG_INTERVAL) \
	       odir.var=$(GCP_DSUB_DIRECT_ODIR_VAR) \
	       out.dir=$($(GCP_DSUB_DIRECT_ODIR_VAR)) \
	       command='$(GCP_DSUB_DIRECT_COMMAND)' \
	       ifn.vars="$(GCP_DSUB_DIRECT_IFN_VARS)" \
	       ifn.paths="$(foreach X,$(GCP_DSUB_DIRECT_IFN_VARS),$($X))" \
	       ofn.vars="$(GCP_DSUB_DIRECT_OFN_VARS)" \
	       ofn.paths="$(foreach X,$(GCP_DSUB_DIRECT_OFN_VARS),$($X))" \
	       odir.vars="$(GCP_DSUB_DIRECT_ODIR_VARS)" \
	       odir.paths="$(foreach X,$(GCP_DSUB_DIRECT_ODIR_VARS),$($X))" \
	       drop.params=$(GCP_DSUB_DROP_PARAMS) \
	       ms.level=$(MS_LEVEL) \
	       job.id=$(PAR_JOB_ID) \
	       email=$(PAR_NOTIFY_EMAIL) \
	       max.report.level=$(PAR_NOTIFY_MAX_LEVEL) \
	       send.email.flag=$(PAR_EMAIL) \
	       sendgrid.key=$(PAR_SENDGRID_API_KEY) \
	       params="DUMMY~1 $(subst =,~,$(GCP_DSUB_MAKEFLAGS))"

dsub_update_local:
	@gsutil ls $(GCP_RSYNC_TARGET_BUCKET) > /dev/null 2>&1; if [ $$? -eq 0 ]; then \
	echo Localizing $(GCP_RSYNC_SRC_VAR) from bucket:; \
	gsutil -mq du -e "*/.dsub/*" -sh $(GCP_RSYNC_TARGET_BUCKET); \
	gsutil -mq rsync -r -u -x ".*\.dsub.*" $(GCP_RSYNC_TARGET_BUCKET) $($(GCP_RSYNC_SRC_VAR)) \
	; fi

dsub_check_space:
	df -h $($(GCP_RSYNC_SRC_VAR)) > $($(GCP_RSYNC_SRC_VAR))/.df

# required in order to run with private network
# see: https://github.com/DataBiosphere/dsub/blob/main/docs/compute_resources.md
dsub_enable_private_network:
	gcloud compute networks subnets update default \
		--region=$(GCP_REGION) \
		--enable-private-ip-google-access

#########################################################################################################
# check
#########################################################################################################

dstat:
	dstat \
		--provider $(GCP_DSUB_PROVIDER) \
		--project $(GCP_PROJECT_ID) \
		--users '*' --wait $X

dstat_s:
	dstat \
		--provider $(GCP_DSUB_PROVIDER) \
		--project $(GCP_PROJECT_ID) \
		--users '*' --wait --summary

dstat_f:
	dstat \
		--provider $(GCP_DSUB_PROVIDER) \
		--project $(GCP_PROJECT_ID) \
		--users '*' -f | grep -A 2 'ms-'

ddel_all:
	ddel \
		--provider $(GCP_DSUB_PROVIDER) \
		--project $(GCP_PROJECT_ID) \
		--users '*' \
		--jobs $X

ddel:
	ddel \
		--provider $(GCP_DSUB_PROVIDER) \
		--project $(GCP_PROJECT_ID) \
		--users '*' \
		--jobs '*' \
		--label 'ms-job-key-1=$X'

#########################################################################################################
# directly call dsub
#########################################################################################################

# very basic unit test of dsub
dsub_unit_test:
	dsub \
	    --provider google-cls-v2 \
	    --project relman-yaffe \
	    --zones $(ZONE) \
	    --image $(GCR_IMAGE_PATH) \
	    --machine-type $(MACHINE_TYPE) \
	    --logging gs://eitany-bucket/.t_dsub_logs \
	    --output OUT=gs://eitany-bucket/.t_dsub_out \
	    --command 'echo hello > $${OUT}' \
	    --credentials-file $(KEY_FILE) \
	    --wait --summary

test_email:
	$(_R) $(_md)/R/dsub_all.r test.email a=1 b=2
