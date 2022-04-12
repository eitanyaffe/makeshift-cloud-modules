units:=par.mk par_email.mk
$(call _register_module,par,$(units),)

###############################################################################################
# general job parameters
###############################################################################################

# can be dsub (through gcp) or local
PAR_TYPE?=dsub

# wait for job to finish
PAR_WAIT?=T

# docker image
PAR_GCR_IMAGE_PATH?=$(GCP_GCR_IMAGE_PATH)

# which module to use
PAR_MODULE?=libs

# name of job
PAR_NAME?=job_name

# for billing purposes
PAR_MS_PROJECT_NAME?=specify_project_name

# parent directory, where we save the job labels and task file
PAR_WORK_DIR?=specify_work_dir

# variable name of the output directory
PAR_ODIR_VAR?=specify_outdir_variable_name

# bucket of the output directory
PAR_ODIR_BUCKET?=specify_output_bucket

PAR_ODIR_BUCKET_BASE?=$(OUTPUT_DIR)

# make target to call
PAR_TARGET?=make_target

# variable name of output directory
PAR_TASK_ODIR_VAR?=o_dir

# variable name of item variable
PAR_TASK_ITEM_VAR?=item

# values of single variable taken from table (for par_tasks_table)
PAR_TASK_ITEM_TABLE?=
PAR_TASK_ITEM_FIELD?=

# multiple variable here (for par_tasks_complex)
PAR_TASK_TABLE?=

# values of items (for par_tasks)
PAR_TASK_ITEM_VALS?=1 2 3

# keep makefile line parameters in order to pass to sub-jobs
ifeq ($(PAR_TYPE),local)
PAR_MAKEOVERRIDES?=
else
PAR_MAKEOVERRIDES?=$(MAKEOVERRIDES)
endif

#PAR_DROP_PARAMS=^m$$ ^DRY$$ ^DUMMY$$ ^PAR_
PAR_DROP_PARAMS=^m$$ ^DRY$$ ^DUMMY$$ ^TOP_WAIT$$

# we keep track of the the nested level
MS_LEVEL?=1

###############################################################################################
# machine spec
###############################################################################################

# style can be custom or defined
PAR_SPEC_STYLE?=defined
PAR_MACHINE?=n1-standard-1

# spec relevant for custom only
PAR_CPU_COUNT?=2
PAR_RAM_GB?=8

# boot disk
PAR_BOOT_GB?=12

# data disk pd-ssd / pd-standard
PAR_DISK_TYPE?=pd-standard
PAR_DISK_GB?=8

###############################################################################################
# remove files and dirs
###############################################################################################

# list of paths to remove
PAR_REMOVE_PATHS?=some_files

PAR_REMOVE_BUCKET?=bucket_of_some_files

###############################################################################################
# dsub specific parameters
###############################################################################################

# number of preemt attempts
PAR_PREEMTIBLE?=1

# number of retries beyond preemtible
PAR_NON_PREEMTIBLE_RETRIES?=0

# rsync from bucket before starting target 
PAR_DOWNLOAD_INTERMEDIATES?=T

# rsync to bucket after every step 
PAR_UPLOAD_INTERMEDIATES?=T

# max tasks run in parallel
PAR_BATCH_SIZE?=1200

# if emails not needed the VM runs on the private network
PAR_EMAIL?=T

###############################################################################################
# job id, shared by entire nested tree
###############################################################################################

# submitting user
PAR_USER?=$(USER)

PAR_DATE?=$(shell date +'%m-%d-%Y')

# optional custom text added by user 
DDESC?=

# directy specied in gcp_dsub.mk, and passed to children as an enviroment variable 
PAR_JOB_ID?=$(PAR_NAME)_$(PAR_DATE)_$(PAR_USER)$(if $(DDESC),_$(DDESC))

###############################################################################################
# direct call to docker without makeshift env
###############################################################################################

# where to keep logs
PAR_DIRECT_LOGDIR?=log_path

# list of variable names of input files
PAR_DIRECT_IFN_VARS?=i_vars

# list of variable names of input dirs
PAR_DIRECT_IDIR_VARS?=NA
PAR_DIRECT_IDIR_BUCKETS?=NA
PAR_DIRECT_IDIR_BASEDIRS?=NA

# list of input files
PAR_DIRECT_IFNS?=ifns

# list of variable names of output files
PAR_DIRECT_OFN_VARS?=NA

# list of variable names of output dirs
PAR_DIRECT_ODIR_VARS?=NA

# list of output files
PAR_DIRECT_OFNS?=ofns

# command to execute
PAR_DIRECT_COMMAND?=command

# typically save job stats but some images don't have nproc or getconf
PAR_SAVE_JOB_STATS?=T

###############################################################################################
# notify to email
###############################################################################################

# email addresses
PAR_NOTIFY_EMAIL?=$(if $(MAKESHIFT_EMAIL),$(MAKESHIFT_EMAIL),NONE)

# message content
PAR_NOTIFY_SUBJECT?=something happened
PAR_NOTIFY_MESSAGE?=this happened

# report nested jobs up to this level
PAR_NOTIFY_MAX_LEVEL?=2

PAR_SENDGRID_API_KEY?=$(if $(SENDGRID_API_KEY),$(SENDGRID_API_KEY),NONE)

####################################################################################
# export data
####################################################################################

PAR_EXPORT_LABEL?=default
BASE_EXPORT_DIR?=$(OUTPUT_DIR)/export/$(PAR_EXPORT_LABEL)
