ORG := cloudbsd
DOMAIN := docker.io
IMGBASE := freebsd-build
FREEBSD_VERSIONS := 15.0 14.3 14.2
ARCHITECTURES := amd64 aarch64
CURRENT_ARCHITECTURE := `uname -m`
DIRS != ls -d */ 2>/dev/null | sed 's|/||' | grep -v '^pkg$$' | grep -v '^\.'

default: all

all: prebuild push

prebuild:
	@echo "ORG: ${ORG}"
	@echo "DOMAIN: ${DOMAIN}"
	@echo "IMGBASE: ${IMGBASE}"
	@echo "FREEBSD_VERSIONS: ${FREEBSD_VERSIONS}"
	@echo "ARCHITECTURES: ${ARCHITECTURES}"
	@echo "CURRENT_ARCHITECTURE: ${CURRENT_ARCHITECTURE}"
	@echo "DIRS: ${DIRS}"

ports:
.if !exists(ports/ports)
	git clone https://github.com/freebsd/freebsd-ports.git -b main ports/ports
.endif

clean:
	@rm -rf pkg/ports


build-ports: ports
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(CURRENT_ARCHITECTURE); do \
			echo "Building FreeBSD $$version:$$arch for ports"; \
			podman build --build-arg FREEBSD_RELEASE=$$version --build-arg ARCHITECTURE=$$arch -f ports/Containerfile -t ${DOMAIN}/${ORG}/${IMGBASE}-ports-$$arch:$$version ;\
		done; \
	done

push-ports: build-ports
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(CURRENT_ARCHITECTURE); do \
			echo "Pushing docker.io/cloudbsd/freebsd-build-ports-$$arch:$$version"; \
			podman push ${DOMAIN}/${ORG}/${IMGBASE}-ports-$$arch:$$version ;\
		done; \
	done

build-pkg: manifestmerge-ports
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(CURRENT_ARCHITECTURE); do \
			echo "Building FreeBSD $$version:$$arch for pkg"; \
			podman build --build-arg FREEBSD_RELEASE=$$version --build-arg ARCHITECTURE=$$arch -f pkg/Containerfile -t ${DOMAIN}/${ORG}/${IMGBASE}-pkg-$$arch:$$version ;\
		done; \
	done

push-pkg: build-pkg
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(CURRENT_ARCHITECTURE); do \
			echo "Pushing docker.io/cloudbsd/freebsd-build-pkg-$$arch:$$version"; \
			podman push ${DOMAIN}/${ORG}/${IMGBASE}-pkg-$$arch:$$version ;\
		done; \
	done

build: manifestmerge-ports manifestmerge-pkg
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

push: build
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

manifestmerge: push
	@for version in $(FREEBSD_VERSIONS); do \
		for dir in $(DIRS); do \
			podman manifest rm ${DOMAIN}/${ORG}/${IMGBASE}-$$dir:$$version | true ; \
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


manifestmerge-pkg: push-pkg
	@for version in $(FREEBSD_VERSIONS); do \
		podman manifest rm ${DOMAIN}/${ORG}/${IMGBASE}-pkg:$$version | true ; \
		podman manifest create ${DOMAIN}/${ORG}/${IMGBASE}-pkg:$$version ; \
		for arch in $(ARCHITECTURES); do \
			COUNT=$$(podman search --list-tags ${DOMAIN}/${ORG}/${IMGBASE}-pkg-$$arch  2>/dev/null | grep $$version | wc -l ); \
			if [ "$$COUNT" -eq 1 ]; then \
				echo "Adding $$arch image to ${DOMAIN}/${ORG}/${IMGBASE}-pkg:$$version"; \
				podman manifest add ${DOMAIN}/${ORG}/${IMGBASE}-pkg:$$version ${DOMAIN}/${ORG}/${IMGBASE}-pkg-$$arch:$$version ;\
			fi; \
		done; \
		podman manifest push ${DOMAIN}/${ORG}/${IMGBASE}-pkg:$$version ; \
	done

manifestmerge-ports: push-ports
	@for version in $(FREEBSD_VERSIONS); do \
		podman manifest rm ${DOMAIN}/${ORG}/${IMGBASE}-ports:$$version | true ; \
		podman manifest create ${DOMAIN}/${ORG}/${IMGBASE}-ports:$$version ; \
		for arch in $(ARCHITECTURES); do \
			COUNT=$$(podman search --list-tags ${DOMAIN}/${ORG}/${IMGBASE}-ports-$$arch  2>/dev/null | grep $$version | wc -l ); \
			if [ "$$COUNT" -eq 1 ]; then \
				echo "Adding $$arch image to ${DOMAIN}/${ORG}/${IMGBASE}-ports:$$version"; \
				podman manifest add ${DOMAIN}/${ORG}/${IMGBASE}-ports:$$version ${DOMAIN}/${ORG}/${IMGBASE}-ports-$$arch:$$version ;\
			fi; \
		done; \
		podman manifest push ${DOMAIN}/${ORG}/${IMGBASE}-ports:$$version ; \
	done

.PHONY: prebuild all build push build-ports build-pkg push-pkg cleanup ports manifestmerge-pkg manifestmerge-ports manifestmerge default