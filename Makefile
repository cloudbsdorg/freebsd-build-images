FREEBSD_VERSIONS := 14.2 14.3 15.snap 16.snap
ARCHITECTURES := amd64
DIRS := openjdk8 openjdk11 openjdk17 openjdk18 openjdk19 openjdk20 openjdk21 openjdk22 openjdk23 openjdk24 openjdk25

default: all

all: build-pkg push-pkg build push

build-pkg:
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(ARCHITECTURES); do \
			echo "Building FreeBSD $$version:$$arch for pkg"; \
			podman build --build-arg FREEBSD_RELEASE=$$version --build-arg ARCHITECTURE=$$arch -f pkg/Containerfile -t docker.io/cloudbsd/freebsd-build-pkg-$$arch:$$version ;\
		done; \
	done

push-pkg:
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(ARCHITECTURES); do \
			echo "Pushing docker.io/cloudbsd/freebsd-build-pkg-$$arch:$$version"; \
			podman push docker.io/cloudbsd/freebsd-build-pkg-$$arch:$$version ;\
		done; \
	done

build:
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(ARCHITECTURES); do \
		  for dir in $(DIRS); do \
			if grep -q "^$$version:$$arch$$" $$dir/RELEASES; then \
				  echo "Building FreeBSD $$version:$$arch for $$dir"; \
				  podman build --build-arg FREEBSD_RELEASE=$$version --build-arg ARCHITECTURE=$$arch -f $$dir/Containerfile -t docker.io/cloudbsd/freebsd-build-$$dir-$$arch:$$version ;\
			fi; \
		  done; \
		done; \
	done

push:
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(ARCHITECTURES); do \
		  for dir in $(DIRS); do \
			if grep -q "^$$version:$$arch$$" $$dir/RELEASES; then \
					echo "Pushing FreeBSD $$version:$$arch for $$dir"; \
					podman push cloudbsd/freebsd-build-$$dir-$$arch:$$version ;\
			fi; \
		  done; \
		done; \
	done

.PHONY: all build push default