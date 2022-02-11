LOCAL_TAR?=$(GCP_DOWNLOAD_WORK_DIR)/data.tar

download_seq:
	mkdir -p $(GCP_DOWNLOAD_WORK_DIR)
	curl -o $(LOCAL_TAR).bz2 -L $(GCP_DOWNLOAD_URL)
	lbzip2 -n 32 -d $(LOCAL_TAR).bz2
	tar tf $(LOCAL_TAR)
	cd $(GCP_DOWNLOAD_WORK_DIR) && tar xvf $(LOCAL_TAR) && rm $(LOCAL_TAR)
	gsutil -m rsync -x ".dsub*" -R $(GCP_DOWNLOAD_WORK_DIR) $(GCP_DOWNLOAD_DESTINATION_BUCKET)
	rm -rf `ls $(GCP_DOWNLOAD_WORK_DIR) | grep -v ".dsub*"`

d_download_seq:
	mkdir -p $(GCP_DOWNLOAD_WORK_DIR)
	$(MAKE) m=par par \
		PAR_WORK_DIR=$(GCP_DOWNLOAD_WORK_DIR) \
		PAR_MODULE=gcp \
		PAR_MACHINE=$(GCP_DOWNLOAD_MACHINE) \
		PAR_DISK_TYPE=pd-ssd \
		PAR_DISK_GB=$(GCP_DOWNLOAD_DISK_GB) \
		PAR_NAME=gcp_download \
		PAR_ODIR_VAR=GCP_DOWNLOAD_WORK_DIR \
		PAR_TARGET=download_seq \
		PAR_PREEMTIBLE=0 \
		PAR_WAIT=$(TOP_WAIT) \
		PAR_MAKEFLAGS="$(PAR_MAKEOVERRIDES)"
