
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

# push image to GCR
mdocker_push:
	docker push $(GCP_GCR_IMAGE_PATH)

# push image to dockerhub
mdocker_push_dc:
	docker tag $(GCP_IMAGE_NAME) $(GCP_DOCKERHUB_IMAGE)
	docker push $(GCP_DOCKERHUB_IMAGE)

