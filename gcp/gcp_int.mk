units:=gcp_dsub.mk gcp_env.mk gcp_sync.mk gcp_image.mk gcp_buckets.mk gcp_download.mk
$(call _register_module,gcp,$(units),)

# json key file
GCP_KEY_FILE?=$(GOOGLE_APPLICATION_CREDENTIALS)

GCP_PIPELINE_RELATIVE_DIR:=$(subst $(MAKESHIFT_ROOT)/,,$(CURDIR))

###############################################################################################
# makeshift bucket
###############################################################################################

# makeshift code placed in bucket
GCP_MAKESHIFT_BUCKET_BASE?=ms-$(PAR_MS_PROJECT_NAME)-code
GCP_MAKESHIFT_BUCKET?=gs://$(GCP_MAKESHIFT_BUCKET_BASE)

# makeshift config files placed in a separate bucket
GCP_MAKESHIFT_CONFIG_BUCKET_BASE?=ms-$(PAR_MS_PROJECT_NAME)-config
GCP_MAKESHIFT_CONFIG_BUCKET?=gs://$(GCP_MAKESHIFT_CONFIG_BUCKET_BASE)

# compiled programs placed in separate bucket
BINARY_BUCKET?=gs://ms-$(PIPELINE_NAME)-bin

# explicitely include all relevant modules
GCP_MAKESHIFT_MODULES?=par gcp

GCP_MAKESHIFT_EXTRA?=

###############################################################################################
# account details
###############################################################################################

GCP_PROJECT_ID?=relman-yaffe

# default dsub regions
GCP_REGION?=us-west1
GCP_ZONE?=$(GCP_REGION)-a

# default bucket location
GCP_LOCATION?=us-west1

###############################################################################################
# mdocker image
###############################################################################################

GCP_IMAGE_NAME=mdocker-base
GCP_GCR_HOSTNAME=gcr.io
GCP_GCR_IMAGE_PATH=$(GCP_GCR_HOSTNAME)/$(GCP_PROJECT_ID)/$(GCP_IMAGE_NAME)

GCP_DSUB_PROVIDER?=google-cls-v2

###############################################################################################
# basic input/output dirs
###############################################################################################

GCP_MOUNT_BASE_DIR?=/makeshift-mnt

# root of input and output
INPUT_DIR?=$(GCP_MOUNT_BASE_DIR)/input
OUTPUT_DIR?=$(GCP_MOUNT_BASE_DIR)/output

# makeshift binary files
BIN_DIR?=$(GCP_MOUNT_BASE_DIR)/bin

###############################################################################################
# mount buckets
###############################################################################################

# relevant when creating bucket
GCP_CLASS?=standard

# full bucket path to mount
GCP_MOUNT_BUCKET?=gs://$(USER)-test-bucket

# variable name of mounted path
GCP_MOUNT_VAR?=OUTPUT_DIR

# multiple mounts supported using classes
$(call _class,gmount,GCP_MOUNT_BUCKET GCP_CLASS GCP_MOUNT_VAR)

# example with two mounts:
# $(call _class_instance,gmount,C1,gs://bucket1 standard OUTPUT_DIR1)
# $(call _class_instance,gmount,C2,gs://bucket2 standard OUTPUT_DIR2)

###############################################################################################
# mount bucket internal
###############################################################################################

GCP_MOUNT_FILE_MODE?=755

# local dir of path, used in containers run directly with docker
# dsub have their own private directory structure
GCP_MOUNT_DIR?=$($(GCP_MOUNT_VAR))

# bucket short name
GCP_MOUNT_BUCKET_SHORT?=$(subst gs://,,$(GCP_MOUNT_BUCKET))

# lists are needed for dsub
GCP_MOUNT_BUCKETS=$(call _class_variable_list,gmount,GCP_MOUNT_BUCKET)
GCP_MOUNT_VARS=$(call _class_variable_list,gmount,GCP_MOUNT_VAR)

GCP_GCSFUSE_IMPLICIT_DIRS?=T

ifeq ($(GCP_GCSFUSE_IMPLICIT_DIRS), T)
GCP_GCSFUSE_EXTRA?=--implicit-dirs
else
GCP_GCSFUSE_EXTRA?=
endif

###############################################################################################
# VM with mdocker image
###############################################################################################

GCP_VM_IMAGE_NAME=makeshift-image
GCP_VM_NAME=makeshift-control-vm

###############################################################################################
# machine spec
###############################################################################################

# style can be custom or defined
GCP_DSUB_SPEC_STYLE?=$(PAR_SPEC_STYLE)
GCP_DSUB_MACHINE?=$(PAR_MACHINE)

# spec relevant for custom only
GCP_DSUB_CPU_COUNT?=$(PAR_CPU_COUNT)
GCP_DSUB_RAM_GB?=$(PAR_RAM_GB)

# boot disk
GCP_DSUB_BOOT_GB?=$(PAR_BOOT_GB)

# data disk
GCP_DSUB_DISK_TYPE?=$(PAR_DISK_TYPE)
GCP_DSUB_DISK_GB?=$(PAR_DISK_GB)

###############################################################################################
# dsub
###############################################################################################

# which module to use
GCP_DSUB_MODULE?=$(PAR_MODULE)

# wait for job
GCP_DSUB_WAIT?=T

# variable name of the output directory
GCP_DSUB_ODIR_VAR?=specify_outdir_variable_name

# bucket of the output directory
GCP_DSUB_ODIR_BUCKET?=specify_output_bucket

GCP_DSUB_ODIR_BUCKET_BASE?=$(OUTPUT_DIR)

# must be defined by call
GCP_DSUB_TARGET?=target

# label of dsub job
GCP_DSUB_NAME?=dsub_name

# label of dsub job
GCP_MS_PROJECT_NAME?=$(PAR_MS_PROJECT_NAME)

# mount locally under here
GCP_LOCAL_MOUNT_PATH?=$(HOME)/$(PAR_MS_PROJECT_NAME)

GCP_DSUB_DROP_PARAMS=$(PAR_DROP_PARAMS)

GCP_DSUB_PREEMTIBLE?=$(PAR_PREEMTIBLE)

GCP_DSUB_DOWNLOAD_INTERMEDIATES?=$(PAR_DOWNLOAD_INTERMEDIATES)
GCP_DSUB_UPLOAD_INTERMEDIATES?=$(PAR_UPLOAD_INTERMEDIATES)

# relevant for download intermediates
GCP_RSYNC_SRC_VAR?=not_defined
GCP_RSYNC_SRC?=$($(GCP_RSYNC_SRC_VAR))
GCP_RSYNC_TARGET_BUCKET?=target_bucket

GCP_DSUB_LOG_INTERVAL?=1m

# max tasks run in parallel
GCP_BATCH_SIZE?=$(PAR_BATCH_SIZE)

###############################################################################################
# dsub tasks
###############################################################################################

# input table with variables as columns
GCP_DSUB_TASK_TABLE?=some_table

###############################################################################################
# dsub direct
###############################################################################################

# directly call command without makeshift

# where to keep logs
GCP_DSUB_DIRECT_LOGDIR?=log_path

# list of variable names of input files
GCP_DSUB_DIRECT_IFN_VARS?=i_vars

# list of input files
GCP_DSUB_DIRECT_IFNS?=ifns

# list of variable names of output files
GCP_DSUB_DIRECT_OFN_VARS?=$(PAR_DIRECT_OFN_VARS)

# list of variable names of output directories
GCP_DSUB_DIRECT_ODIR_VARS?=$(PAR_DIRECT_ODIR_VARS)

# list of output files
GCP_DSUB_DIRECT_OFNS?=ofns

# command to execute
GCP_DSUB_DIRECT_COMMAND?=command

###############################################################################################
# remove files and dirs
###############################################################################################

# list of paths to remove
GCP_REMOVE_PATHS?=some_files

###############################################################################################
# bucket disk usage
###############################################################################################

# bucket depth table
GCP_DU_DEPTH_TABLE?=some_file

# also include buckets not mentioned in depth table
GCP_DU_CHECK_ALL?=T

# du expansion depth
GCP_DU_DEPTH?=2

# when printing total space
GCP_DU_TOTAL_UNIT?=TiB

###############################################################################################
# download sequence data
###############################################################################################

# url of the a tarball compressed by bz2 data files
GCP_DOWNLOAD_URL?="specify_download_url"

# files will be stored on this bucket
GCP_DOWNLOAD_DESTINATION_BUCKET?=specify_destination_bucket

GCP_DOWNLOAD_MACHINE?=n2-standard-32
GCP_DOWNLOAD_DISK_GB?=1000

# work dir will contain download logs
GCP_DOWNLOAD_ID?=d1
GCP_DOWNLOAD_WORK_DIR?=$(OUTPUT_DIR)/download/$(GCP_DOWNLOAD_ID)

