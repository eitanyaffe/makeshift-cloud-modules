GCP_DOWNLOAD_TMP_DIR?=$(GCP_DOWNLOAD_WORK_DIR)/tmp
GCP_DOWNLOAD_INFO_DIR?=$(GCP_DOWNLOAD_WORK_DIR)/info
LOCAL_TAR?=$(GCP_DOWNLOAD_TMP_DIR)/data.tar

download_seq:
	$(_start)
	mkdir -p $(GCP_DOWNLOAD_TMP_DIR)
	curl -s -o $(LOCAL_TAR).bz2 -L "$(GCP_DOWNLOAD_URL)"
	lbzip2 -n 32 -d $(LOCAL_TAR).bz2
	tar tf $(LOCAL_TAR)
	cd $(GCP_DOWNLOAD_TMP_DIR) && tar xvf $(LOCAL_TAR) && rm $(LOCAL_TAR)
#	gsutil -m rsync -x ".dsub*" -R $(GCP_DOWNLOAD_TMP_DIR) $(GCP_DOWNLOAD_DESTINATION_BUCKET)
	gsutil -mq cp -R "$(GCP_DOWNLOAD_TMP_DIR)/*" $(GCP_DOWNLOAD_DESTINATION_BUCKET)
	rm -rf $(GCP_DOWNLOAD_TMP_DIR)/*
	$(_end)

# multiple URLs
download_seqs:
	$(MAKE) class_loop class=url t=download_seq

DOWNLOAD_TARGET?=download_seq
d_download_seq:
	mkdir -p $(GCP_DOWNLOAD_INFO_DIR)
	$(MAKE) m=par par \
		PAR_WORK_DIR=$(GCP_DOWNLOAD_INFO_DIR) \
		PAR_MODULE=gcp \
		PAR_MACHINE=$(GCP_DOWNLOAD_MACHINE) \
		PAR_DISK_TYPE=pd-ssd \
		PAR_DISK_GB=$(GCP_DOWNLOAD_DISK_GB) \
		PAR_NAME=gcp_download \
		PAR_ODIR_VAR=GCP_DOWNLOAD_TMP_DIR \
		PAR_TARGET=$(DOWNLOAD_TARGET) \
		PAR_PREEMTIBLE=0 \
		PAR_WAIT=$(TOP_WAIT) \
		PAR_MAKEFLAGS="$(PAR_MAKEOVERRIDES)"

d_download_seqs:
	$(MAKE) d_download_seq DOWNLOAD_TARGET=download_seqs
