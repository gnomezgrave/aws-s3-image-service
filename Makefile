BASE_STACK_NAME=image-service
PROJECT=image-service
LOGGER ?= DEBUG
STACK_NAME_SUFFIX ?= $(USER)
BUILD_BUCKET ?= $(USER)-build-bucket
ENV?=dev

IMAGES_PREFIX?=original-images

TARGET_TPL=api
TPL=cloudformation/template.yaml
PACKAGED_TPL=$(TARGET_TPL)-packaged-cloudformation-template.yaml

.PHONY: sync build get-dependencies package deploy release clean test test-coverage


init:
	aws s3 mb s3://$(BUILD_BUCKET) && echo "Bucket Created" || echo "Bucket already exists!"
	@echo "Test"
	python3 -m venv .venv
	@echo Please run \"source .venv/bin/activate\" to activate the Python environment.

clean:
	@echo "Cleaning old build files..."
	@find . -name "*.pyc" -exec rm -f {} \;
	@rm -rf _build

sync:
	@mkdir -p _build/
	@cp -R src/* _build/

get-dependencies: clean
	@mkdir -p _build
	./get_dependencies.sh


package:
	@mkdir -p _build
	@echo "Preparing and uploading AWS package for $(TPL) for $(TARGET_TPL)."
	aws cloudformation package \
		--template-file $(TPL) \
		--s3-bucket $(BUILD_BUCKET) \
		--s3-prefix packages \
		--output-template-file _build/$(PACKAGED_TPL)

deploy:
	@echo "Deploying template for $(TPL) for $(TARGET_TPL)."
	aws cloudformation deploy \
		--template-file _build/$(PACKAGED_TPL) \
		--stack-name $(BASE_STACK_NAME)--$(TARGET_TPL)--$(STACK_NAME_SUFFIX) \
		--capabilities CAPABILITY_NAMED_IAM \
		--no-fail-on-empty-changeset \
		--parameter-overrides \
			Environment=$(ENV) \
			LogLevel=$(LOGGER) \
			OriginalImagesPrefix=$(IMAGES_PREFIX) \
		--tags Project=$(PROJECT) Owner=$(USER) Environment=$(ENV)

release: get-dependencies sync package deploy
	@echo "CloudFormation stacks deployment completed"

_delete:

	@$(eval STACK := $(BASE_STACK_NAME)--$(TARGET_TPL)--$(STACK_NAME_SUFFIX))
	@echo "Deleting $(STACK)"
	@$(eval OUT:= $(shell aws cloudformation list-stack-resources --stack-name $(STACK) \
		--query 'StackResourceSummaries[?ResourceType==`"AWS::S3::Bucket"` && ResourceStatus!=`"DELETE_COMPLETE"`].PhysicalResourceId' --output text))

	@if [ -n $OUT ]; then \
		echo Starting to empty these buckets : $(OUT); \
		for bucket in $(OUT); do aws s3 rm s3://$$bucket/ --recursive; done \
	fi

	aws cloudformation delete-stack --stack-name $(STACK)
	@echo "Waiting for the stack to be deleted, this may take a few minutes..."
	aws cloudformation wait stack-delete-complete --stack-name $(STACK)
