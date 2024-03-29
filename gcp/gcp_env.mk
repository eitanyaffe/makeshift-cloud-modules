validate_env:
	$(call _assert,MAKESHIFT_ROOT MAKESHIFT_CONFIG GCP_PROJECT_ID)
	@echo "====================================================================================="
	@echo "MakeShift environment variables:"
	@echo MAKESHIFT_ROOT=$(MAKESHIFT_ROOT)
	@echo MAKESHIFT_CONFIG=$(MAKESHIFT_CONFIG)
	@echo GCP_PROJECT_ID=$(GCP_PROJECT_ID)
	@echo "====================================================================================="

# to remove docker from quarantine on macos run 'xattr -d com.apple.quarantine /usr/local/bin/docker'

# note: --privileged might be needed to run docker within docker, in case debugging inner docker run from environment
# run image locally with X11
denv_old: validate_env
	docker run --rm -it \
	       --cap-add SYS_ADMIN --device /dev/fuse --security-opt apparmor:unconfined \
	       -v /tmp/.X11-unix:/tmp/.X11-unix \
	       -e DISPLAY=host.docker.internal:0 \
	       -e MAKESHIFT_ROOT=/makeshift \
	       -e MAKESHIFT_LOCAL_PATH=$(MAKESHIFT_ROOT) \
	       -v $(MAKESHIFT_ROOT):/makeshift \
	       -e MAKESHIFT_CONFIG=/makeshift-config \
	       -e GCP_PROJECT_ID=$(GCP_PROJECT_ID) \
	       -v $(MAKESHIFT_CONFIG):/makeshift-config \
	       -v $(dir $(MAKESHIFT_GCP_KEY)):/keys \
	       -e GOOGLE_APPLICATION_CREDENTIALS=/keys/$(notdir $(MAKESHIFT_GCP_KEY)) \
	       -e SENDGRID_API_KEY=$(PAR_SENDGRID_API_KEY) \
	       -e PAR_NOTIFY_EMAIL=$(PAR_NOTIFY_EMAIL) \
	       -e BOTO_CONFIG=/makeshift/.boto \
	       -e USER=$(USER) \
	       -e c=$(c) \
	       -v /tmp:/tmp \
	       -v /var/run/docker.sock:/var/run/docker.sock \
	       -w /makeshift/$(GCP_PIPELINE_RELATIVE_DIR) \
	       $(GCP_GCR_IMAGE_PATH) \
	       bash -c "echo \"export PS1='[[$(PIPELINE_NAME):$(PROJECT_NAME)]] \w % '\" >> ~/.bashrc && make m=gcp mount_buckets bucket_summary && bash"; echo "RC=$$?"; date

CONTAINER_NAME:=$(PIPELINE_NAME)-$(PROJECT_NAME)-$(shell bash -c 'echo $$RANDOM')
denv: validate_env
	docker run -d -it --name $(CONTAINER_NAME) \
	       --cap-add SYS_ADMIN --device /dev/fuse --security-opt apparmor:unconfined \
	       -v /tmp/.X11-unix:/tmp/.X11-unix \
	       -e DISPLAY=host.docker.internal:0 \
	       -e MAKESHIFT_ROOT=/makeshift \
	       -e MAKESHIFT_LOCAL_PATH=$(MAKESHIFT_ROOT) \
	       -v $(MAKESHIFT_ROOT):/makeshift \
	       -e MAKESHIFT_CONFIG=/makeshift-config \
	       -e GCP_PROJECT_ID=$(GCP_PROJECT_ID) \
	       -v $(MAKESHIFT_CONFIG):/makeshift-config \
	       -v $(dir $(MAKESHIFT_GCP_KEY)):/keys \
	       -e GOOGLE_APPLICATION_CREDENTIALS=/keys/$(notdir $(MAKESHIFT_GCP_KEY)) \
	       -e SENDGRID_API_KEY=$(PAR_SENDGRID_API_KEY) \
	       -e PAR_NOTIFY_EMAIL=$(PAR_NOTIFY_EMAIL) \
	       -e BOTO_CONFIG=/makeshift/.boto \
	       -e USER=$(USER) \
	       -e c=$(c) \
	       -v /tmp:/tmp \
	       -v /var/run/docker.sock:/var/run/docker.sock \
	       -w /makeshift/$(GCP_PIPELINE_RELATIVE_DIR) \
	       $(GCP_GCR_IMAGE_PATH) \
	       bash -c "echo \"export PS1='[[$(PIPELINE_NAME):$(PROJECT_NAME)]] \w % '\" >> ~/.bashrc && make m=gcp mount_buckets bucket_summary && bash"
	docker attach $(CONTAINER_NAME); echo "RC=$$?"; date
	docker rm $(CONTAINER_NAME)

CONTAINER_NAME:=$(PIPELINE_NAME)-$(PROJECT_NAME)-$(shell bash -c 'echo $$RANDOM')
denv2:
	docker run -d -it --name $(CONTAINER_NAME) \
	       --cap-add SYS_ADMIN --device /dev/fuse --security-opt apparmor:unconfined \
	       -v /tmp/.X11-unix:/tmp/.X11-unix \
	       -e DISPLAY=host.docker.internal:0 \
	       -e MAKESHIFT_ROOT=/makeshift \
	       -e MAKESHIFT_LOCAL_PATH=$(MAKESHIFT_ROOT) \
	       -v $(MAKESHIFT_ROOT):/makeshift \
	       -e MAKESHIFT_CONFIG=/makeshift-config \
	       -e GCP_PROJECT_ID=$(GCP_PROJECT_ID) \
	       -v $(MAKESHIFT_CONFIG):/makeshift-config \
	       -v $(dir $(MAKESHIFT_GCP_KEY)):/keys \
	       -e GOOGLE_APPLICATION_CREDENTIALS=/keys/$(notdir $(MAKESHIFT_GCP_KEY)) \
	       -e SENDGRID_API_KEY=$(PAR_SENDGRID_API_KEY) \
	       -e PAR_NOTIFY_EMAIL=$(PAR_NOTIFY_EMAIL) \
	       -e BOTO_CONFIG=/makeshift/.boto \
	       -e USER=$(USER) \
	       -e c=$(c) \
	       -v /tmp:/tmp \
	       -v /var/run/docker.sock:/var/run/docker.sock \
	       -w /makeshift/$(GCP_PIPELINE_RELATIVE_DIR) \
	       $(GCP_GCR_IMAGE_PATH) \
	       bash -c "echo \"export PS1='[[$(PIPELINE_NAME):$(PROJECT_NAME)]] \w % '\" >> ~/.bashrc && bash"
	docker attach $(CONTAINER_NAME); echo "RC=$$?"; date

# all system logs:
# sudo log collect --last 1h --output macos

# docker logs from system
# pred='process matches ".*(ocker|vpnkit).*" || (process in {"taskgated-helper", "launchservicesd", "kernel"} && eventMessage contains[c] "docker")'
# /usr/bin/log show --debug --info --style syslog --last 1h --predicate "$pred" >/tmp/logs.txt


# docker logs:
# cp ~/Library/Containers/com.docker.docker/Data/log/vm/dockerd.log . 
# cp ~/Library/Containers/com.docker.docker/Data/log/vm/containerd.log .
# cp ~/Library/Containers/com.docker.docker/Data/vms/0/console-ring .

# shim explained: https://iximiuz.com/en/posts/implementing-container-runtime-shim

# run in VM
venv:
	cat $(MAKESHIFT_ROOT)/key.json | sudo docker login -u _json_key --password-stdin https://gcr.io
	sudo docker run --rm -it --privileged \
	       -v /tmp/.X11-unix:/tmp/.X11-unix \
	       -e DISPLAY=host.docker.internal:0 \
	       -e MAKESHIFT_ROOT=/makeshift \
	       -e MAKESHIFT_CONFIG=/makeshift-config \
	       -v /makeshift:/makeshift \
	       -e GOOGLE_APPLICATION_CREDENTIALS=/makeshift/key.json \
	       -e USER=$(USER) \
	       -e BOTO_CONFIG=/makeshift/.boto \
	       -v /var/run/docker.sock:/var/run/docker.sock \
	       -w /makeshift/$(GCP_PIPELINE_RELATIVE_DIR) \
	       $(GCP_GCR_IMAGE_PATH) 'bash'

# makeshift mounted through bucket
denv_bucket:
	docker run --rm -it --privileged \
	       -v /tmp/.X11-unix:/tmp/.X11-unix \
	       -e DISPLAY=host.docker.internal:0 \
	       -e MAKESHIFT_BUCKET_BASE=$(GCP_MAKESHIFT_BUCKET_BASE) \
	       -e MAKESHIFT_ROOT=/makeshift \
	       -e MAKESHIFT_CONFIG=/makeshift-config \
	       -e GOOGLE_APPLICATION_CREDENTIALS=/makeshift/key.json \
	       -e BOTO_CONFIG=/makeshift/.boto \
	       -v /Users/eitany/work/makeshift:/makeshift_local \
	       -v /var/run/docker.sock:/var/run/docker.sock \
	       $(GCR_IMAGE_PATH) /bin/bash

vm_no_container:
	gcloud compute \
	  --project=$(GCP_PROJECT_ID) \
	  instances create $(VGCP_M_NAME) \
	  --zone=$(GCP_ZONE) \
	  --machine-type=$(GCP_MACHINE_TYPE) \
	  --metadata=google-logging-enabled=true \
	  --scopes=https://www.googleapis.com/auth/cloud-platform \
	  --network-tier=STANDARD \
	  --image-project=$(GCP_PROJECT_ID) \
	  --image=$(GCP_VM_IMAGE_NAME) \
	  --enable-display-device

vm:
	gcloud compute \
	  --project=$(GCP_PROJECT_ID) \
	  instances create-with-container $(GCP_VM_NAME) \
	  --zone=$(GCP_ZONE) \
	  --machine-type=$(GCP_MACHINE_TYPE) \
	  --network-tier=STANDARD \
	  --metadata=google-logging-enabled=true \
	  --maintenance-policy=MIGRATE \
	  --scopes=https://www.googleapis.com/auth/cloud-platform \
	  --image-family=cos-stable \
	  --image-project=cos-cloud \
	  --boot-disk-size=10GB \
	  --boot-disk-type=pd-standard \
	  --boot-disk-device-name=$(GCP_VM_NAME) \
	  --container-image=$(GCP_GCR_IMAGE_PATH) \
	  --container-privileged \
	  --container-mount-host-path=host-path=/var/run/docker.sock,mount-path=/var/run/docker.sock \
	  --container-env="MAKESHIFT_BUCKET_BASE=$(GCP_MAKESHIFT_BUCKET_BASE),MAKESHIFT_ROOT=/makeshift,MAKESHIFT_CONFIG=/makeshift-config" \
	  --container-restart-policy=on-failure \
	  --container-stdin \
	  --container-tty

# must run in container
# gcsfuse --implicit-dirs eitany-makeshift-bucket /makeshift

vm_update:
	gcloud compute \
	  --project=$(GCP_PROJECT_ID) instances update-container \
	  $(VM_NAME) \
	  --zone=$(ZONE) \
	  --container-image=$(GCP_GCR_IMAGE_PATH) \
	  --container-privileged \
	  --container-env="MAKESHIFT_BUCKET_BASE=$(GCP_MAKESHIFT_BUCKET_BASE),MAKESHIFT_ROOT=/makeshift,MAKESHIFT_CONFIG=/makeshift-config" \
	  --container-mount-host-path=host-path=/var/run/docker.sock,mount-path=/var/run/docker.sock \
	  --container-restart-policy=on-failure \
	  --container-tty

vm_kill:
	gcloud compute instances delete $(GCP_VM_NAME) --zone=$(GCP_ZONE) --delete-disks all

vm_ssh:
	gcloud compute ssh \
		$(GCP_VM_NAME) \
		--zone=$(GCP_ZONE)

ssh:
	gcloud compute ssh \
		$(GCP_VM_NAME) \
		--zone=$(GCP_ZONE)

list:
	gcloud compute instances list
