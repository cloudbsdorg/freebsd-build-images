ORG := cloudbsd
DOMAIN := docker.io
IMGBASE := freebsd-build
FREEBSD_VERSIONS := 14.2 14.3
ARCHITECTURES := amd64
CURRENT_ARCHITECTURE := $(shell uname -m)
DIRS := openjdk8 openjdk11 openjdk17 openjdk18 openjdk19 openjdk20 openjdk21 openjdk22 openjdk23 openjdk24 openjdk25

default: all

all: build-pkg push-pkg build push cleanup

ports:
	@rm -rf pkg/ports
	git clone https://github.com/freebsd/freebsd-ports.git -b main pkg/ports

cleanup:
	@rm -rf pkg/ports

build-pkg:
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(CURRENT_ARCHITECTURE); do \
			echo "Building FreeBSD $$version:$$arch for pkg"; \
			podman build --build-arg FREEBSD_RELEASE=$$version --build-arg ARCHITECTURE=$$arch -f pkg/Containerfile -t ${DOMAIN}/${ORG}/${IMGBASE}-pkg-$$arch:$$version ;\
		done; \
	done

push-pkg:
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(CURRENT_ARCHITECTURE); do \
			echo "Pushing docker.io/cloudbsd/freebsd-build-pkg-$$arch:$$version"; \
			podman push ${DOMAIN}/${ORG}/${IMGBASE}-pkg-$$arch:$$version ;\
		done; \
	done

build:
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(CURRENT_ARCHITECTURE); do \
		  for dir in $(DIRS); do \
			if grep -q "^$$version:$$arch$$" $$dir/RELEASES; then \
				  echo "Building FreeBSD $$version:$$arch for $$dir"; \
				  podman build --build-arg FREEBSD_RELEASE=$$version --build-arg ARCHITECTURE=$$arch -f $$dir/Containerfile -t ${DOMAIN}/${ORG}/${IMGBASE}-$$dir-$$arch:$$version  ;\
			fi; \
		  done; \
		done; \
	done

push:
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(CURRENT_ARCHITECTURE); do \
		  for dir in $(DIRS); do \
		    echo "Pushing FreeBSD $$version:$$arch for $$dir"; \
			if grep -q "^$$version:$$arch$$" $$dir/RELEASES; then \
					echo "Pushing FreeBSD $$version:$$arch for $$dir"; \
					podman push ${DOMAIN}/${ORG}/${IMGBASE}-$$dir-$$arch:$$version ;\
			fi; \
		  done; \
		done; \
	done

.PHONY: all build push default