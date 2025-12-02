ORG := cloudbsd
DOMAIN := docker.io
IMGBASE := freebsd-build
FREEBSD_VERSIONS := 14.3 14.2
ARCHITECTURES := amd64 aarch64
CURRENT_ARCHITECTURE := `uname -m`
DIRS := $(filter-out pkg .%, $(patsubst %/,%,$(wildcard */)))

default: all

all: prebuild build-pkg push-pkg build push clean

prebuild:
	@echo "ORG: ${ORG}"
	@echo "DOMAIN: ${DOMAIN}"
	@echo "IMGBASE: ${IMGBASE}"
	@echo "FREEBSD_VERSIONS: ${FREEBSD_VERSIONS}"
	@echo "ARCHITECTURES: ${ARCHITECTURES}"
	@echo "CURRENT_ARCHITECTURE: ${CURRENT_ARCHITECTURE}"
	@echo "DIRS: ${DIRS}"

ports:
.if !exists(pkg/ports)
	git clone https://github.com/freebsd/freebsd-ports.git -b main pkg/ports
.endif

clean:
	@rm -rf pkg/ports

build-pkg: ports
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

manifestmerge:
	@for version in $(FREEBSD_VERSIONS); do \
		for dir in $(DIRS); do \
			podman manifest create ${DOMAIN}/${ORG}/${IMGBASE}-$$dir:$$version ; \
			for arch in $(ARCHITECTURES); do \
				COUNT=$$(podman search --list-tags ${DOMAIN}/${ORG}/${IMGBASE}-$$dir-$$arch  2>/dev/null | grep $$version | wc -l ); \
				if [ "$$COUNT" -eq 1 ]; then \
					echo "Adding $$arch image to ${DOMAIN}/${ORG}/${IMGBASE}-$$dir:$$version"; \
					podman manifest add ${DOMAIN}/${ORG}/${IMGBASE}-$$dir:$$version ${DOMAIN}/${ORG}/${IMGBASE}-$$dir-$$arch:$$version ;\
				fi; \
			done; \
		  	podman manifest push ${DOMAIN}/${ORG}/${IMGBASE}-$$dir:$$version ; \
		done; \
	done

.PHONY: prebuild all build push build-pkg push-pkg cleanup ports manifestmerge default