
# build image
# add  --progress=plain to disable log folding in terminal
mdocker:
	docker build \
		--platform $(GCP_PLATFORM) \
		--load \
		--build-arg GCP_IMAGE_VER=$(GCP_IMAGE_VER) \
		-t $(GCP_IMAGE_NAME) \
		-f $(GCP_CONTAINER_DIR)/Dockerfile \
		$(GCP_CONTAINER_DIR)
	docker tag $(GCP_IMAGE_NAME) $(GCP_GCR_IMAGE_PATH)

# push image to GCR as the SA (not as user), so pushes don't need user reauth
mdocker_push:
	gcloud auth activate-service-account $(GCP_PUSH_ACCOUNT) --key-file=$(GCP_KEY_FILE) --quiet
	CLOUDSDK_CORE_ACCOUNT=$(GCP_PUSH_ACCOUNT) docker push $(GCP_GCR_IMAGE_PATH)

# push image to dockerhub
mdocker_push_dc:
	docker tag $(GCP_IMAGE_NAME) $(GCP_DOCKERHUB_IMAGE)
	docker push $(GCP_DOCKERHUB_IMAGE)

