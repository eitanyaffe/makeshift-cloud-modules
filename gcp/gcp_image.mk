
# build image
mdocker:
	docker build -t $(GCP_IMAGE_NAME) \
		$(_md)/containers/$(GCP_IMAGE_NAME)
	docker tag $(GCP_IMAGE_NAME) $(GCP_GCR_IMAGE_PATH)

# push image to GCR
mdocker_push:
	docker push $(GCP_GCR_IMAGE_PATH)

