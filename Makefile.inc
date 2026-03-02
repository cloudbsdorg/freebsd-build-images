ORG := cloudbsd
DOMAIN := docker.io
IMGBASE := freebsd-build

# Determine the image name based on the current directory
PWD != pwd
DIRNAME != basename $$(dirname ${PWD})
IMAGE_NAME != basename ${PWD}
IMG_FULL_NAME := ${DIRNAME}-${IMAGE_NAME}

default: help

help:
	@echo "Available builds for ${DIRNAME}/${IMAGE_NAME}:"
	@for line in $$(cat RELEASES); do \
		echo "  - VERSION=$${line%%:*} ARCH=$${line#*:}"; \
	done
	@echo ""
	@echo "Targets:"
	@echo "  build   - Build images for specified VERSION and ARCH (defaults to all in RELEASES)"
	@echo "  push    - Build and push images"
	@echo ""
	@echo "Example:"
	@echo "  make build VERSION=14.3 ARCH=amd64"

build:
	@for line in $$(cat RELEASES); do \
		V=$${line%%:*}; \
		A=$${line#*:}; \
		if [ -n "$(VERSION)" ] && [ "$(VERSION)" != "$$V" ]; then continue; fi; \
		if [ -n "$(ARCH)" ] && [ "$(ARCH)" != "$$A" ]; then continue; fi; \
		echo "Building ${DOMAIN}/${ORG}/${IMGBASE}-${IMG_FULL_NAME}-$$A:$$V"; \
		podman build --build-arg FREEBSD_RELEASE=$$V --build-arg ARCHITECTURE=$$A -f Containerfile -t ${DOMAIN}/${ORG}/${IMGBASE}-${IMG_FULL_NAME}-$$A:$$V; \
	done

push: build
	@for line in $$(cat RELEASES); do \
		V=$${line%%:*}; \
		A=$${line#*:}; \
		if [ -n "$(VERSION)" ] && [ "$(VERSION)" != "$$V" ]; then continue; fi; \
		if [ -n "$(ARCH)" ] && [ "$(ARCH)" != "$$A" ]; then continue; fi; \
		echo "Pushing ${DOMAIN}/${ORG}/${IMGBASE}-${IMG_FULL_NAME}-$$A:$$V"; \
		podman push ${DOMAIN}/${ORG}/${IMGBASE}-${IMG_FULL_NAME}-$$A:$$V; \
	done

.PHONY: help build push default
