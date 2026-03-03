ORG := cloudbsd
DOMAIN := docker.io
IMGBASE := freebsd-build

# Determine the image name based on the current directory
PWD != pwd
DIRNAME != basename $$(dirname ${PWD})
IMAGE_NAME != basename ${PWD}
IMG_FULL_NAME := ${DIRNAME}-${IMAGE_NAME}
REPORT_FILE != echo .build_report_`date +%Y%m%d_%H%M%S`

# DNS configuration: can be passed as a comma or space separated list (e.g., make DNS=1.1.1.1,8.8.8.8)
DNS ?= 8.8.8.8, 8.8.4.4, 1.1.1.1, 1.0.0.1
# DNS_ARGS converts the DNS variable into --dns=... flags for podman build
DNS_ARGS != if [ -n "$(DNS)" ]; then echo "$(DNS)" | tr ',' ' ' | tr -s ' ' '\n' | sed 's/^/--dns=/'; fi

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
	@rm -f $(REPORT_FILE)
	@for line in $$(cat RELEASES); do \
		V=$${line%%:*}; \
		A=$${line#*:}; \
		if [ -n "$(VERSION)" ] && [ "$(VERSION)" != "$$V" ]; then continue; fi; \
		if [ -n "$(ARCH)" ] && [ "$(ARCH)" != "$$A" ]; then continue; fi; \
		echo "Building ${DOMAIN}/${ORG}/${IMGBASE}-${IMG_FULL_NAME}-$$A:$$V"; \
		podman build $(DNS_ARGS) --build-arg FREEBSD_RELEASE=$$V --build-arg ARCHITECTURE=$$A -f Containerfile -t ${DOMAIN}/${ORG}/${IMGBASE}-${IMG_FULL_NAME}-$$A:$$V .; \
		if [ $$? -eq 0 ]; then \
			echo "SUCCESS: ${IMG_FULL_NAME}-$$A:$$V" >> $(REPORT_FILE); \
		else \
			echo "FAILURE: ${IMG_FULL_NAME}-$$A:$$V" >> $(REPORT_FILE); \
		fi; \
	done
	@echo ""
	@echo "--- Build Report ---"
	@if [ -f $(REPORT_FILE) ]; then \
		cat $(REPORT_FILE); \
		if grep -q "FAILURE:" $(REPORT_FILE); then \
			exit 1; \
		fi; \
	else \
		echo "No builds performed."; \
	fi

push: build
	@for line in $$(cat RELEASES); do \
		V=$${line%%:*}; \
		A=$${line#*:}; \
		if [ -n "$(VERSION)" ] && [ "$(VERSION)" != "$$V" ]; then continue; fi; \
		if [ -n "$(ARCH)" ] && [ "$(ARCH)" != "$$A" ]; then continue; fi; \
		echo "Pushing ${DOMAIN}/${ORG}/${IMGBASE}-${IMG_FULL_NAME}-$$A:$$V"; \
		podman push ${DOMAIN}/${ORG}/${IMGBASE}-${IMG_FULL_NAME}-$$A:$$V; \
		if [ $$? -eq 0 ]; then \
			echo "SUCCESS (push): ${IMG_FULL_NAME}-$$A:$$V" >> $(REPORT_FILE); \
		else \
			echo "FAILURE (push): ${IMG_FULL_NAME}-$$A:$$V" >> $(REPORT_FILE); \
		fi; \
	done
	@echo ""
	@echo "--- Push Report ---"
	@if [ -f $(REPORT_FILE) ]; then \
		cat $(REPORT_FILE); \
		if grep -q "FAILURE (push):" $(REPORT_FILE); then \
			exit 1; \
		fi; \
	fi

clean:
	@rm -f .build_report_*

.PHONY: help build push default
