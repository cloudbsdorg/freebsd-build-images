# Copyright (c) 2026, Mark LaPointe <mark@cloudbsd.org>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

ORG := cloudbsd
DOMAIN := docker.io
IMGBASE := freebsd-build
FREEBSD_VERSIONS := 16.snap 15.0 14.3 14.2
ARCHITECTURES := amd64 aarch64
ARCH ?= $(ARCHITECTURES)
CURRENT_ARCHITECTURE ?= `uname -m`
# DNS configuration: can be passed as a comma or space separated list (e.g., make DNS=1.1.1.1,8.8.8.8)
DNS ?= 8.8.8.8, 8.8.4.4, 1.1.1.1, 1.0.0.1
# DNS_ARGS converts the DNS variable into --dns=... flags for podman build
DNS_ARGS != if [ -n "$(DNS)" ]; then echo "$(DNS)" | tr ',' ' ' | tr -s ' ' '\n' | sed 's/^/--dns=/'; fi
DIRS != find * -type f -name RELEASES | sed 's|/RELEASES||' | sort
DIR ?= $(DIRS)

default: all

all: prebuild push

prebuild:
	@echo "ORG: ${ORG}"
	@echo "DOMAIN: ${DOMAIN}"
	@echo "IMGBASE: ${IMGBASE}"
	@echo "FREEBSD_VERSIONS: ${FREEBSD_VERSIONS}"
	@echo "ARCHITECTURES: ${ARCHITECTURES}"
	@echo "ARCH: ${ARCH}"
	@echo "DNS: ${DNS}"
	@echo "DNS_ARGS: ${DNS_ARGS}"
	@echo "DIRS: ${DIRS}"
	@echo "DIR: ${DIR}"

fetch-ports:
.if !exists(ports-tree)
	git clone https://github.com/freebsd/freebsd-ports.git -b main ports-tree
.endif

clean:
	@rm -rf ports-tree


# build-ports-tree: Clones the ports tree and builds the ports-tree image
# Note: FreeBSD versions < 15.0 require specific build arguments (SRCIMAGENAME)
build-ports-tree: fetch-ports
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(ARCH); do \
			echo "Building FreeBSD $$version:$$arch for ports-tree"; \
			if [ $$(echo "$$version < 15.0" | sed 's/\.snap//g' | bc) -eq 1 ]; then \
				podman build $(DNS_ARGS) --build-arg FREEBSD_RELEASE=$$version --build-arg ARCHITECTURE=$$arch --build-arg SRCIMAGENAME=freebsd-runtime -f ports/Containerfile -t ${DOMAIN}/${ORG}/${IMGBASE}-ports-tree-$$arch:$$version . ; \
			else \
				podman build $(DNS_ARGS) --build-arg FREEBSD_RELEASE=$$version --build-arg ARCHITECTURE=$$arch -f ports/Containerfile -t ${DOMAIN}/${ORG}/${IMGBASE}-ports-tree-$$arch:$$version . ; \
			fi ; \
		done; \
	done

push-ports-tree: build-ports-tree
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(ARCH); do \
			echo "Pushing ${DOMAIN}/${ORG}/${IMGBASE}-ports-tree-$$arch:$$version"; \
			podman push ${DOMAIN}/${ORG}/${IMGBASE}-ports-tree-$$arch:$$version ;\
		done; \
	done

build-pkg: manifestmerge-ports-tree
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(ARCH); do \
			echo "Building FreeBSD $$version:$$arch for pkg"; \
			podman build $(DNS_ARGS) --build-arg FREEBSD_RELEASE=$$version --build-arg ARCHITECTURE=$$arch -f pkg/Containerfile -t ${DOMAIN}/${ORG}/${IMGBASE}-pkg-$$arch:$$version . ;\
		done; \
	done

push-pkg: build-pkg
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(ARCH); do \
			echo "Pushing ${DOMAIN}/${ORG}/${IMGBASE}-pkg-$$arch:$$version"; \
			podman push ${DOMAIN}/${ORG}/${IMGBASE}-pkg-$$arch:$$version ;\
		done; \
	done

build: manifestmerge-ports-tree manifestmerge-pkg
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(ARCH); do \
		  for dir in $(DIR); do \
			if grep -q "^$$version:$$arch$$" $$dir/RELEASES; then \
				  echo "Building FreeBSD $$version:$$arch for $$dir"; \
				  IMGNAME=$$(echo $$dir | sed 's|/|-|g') ; \
				  podman build $(DNS_ARGS) --build-arg FREEBSD_RELEASE=$$version --build-arg ARCHITECTURE=$$arch -f $$dir/Containerfile -t ${DOMAIN}/${ORG}/${IMGBASE}-$$IMGNAME-$$arch:$$version . ;\
			fi; \
		  done; \
		done; \
	done

push: build
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(ARCH); do \
		  for dir in $(DIR); do \
		    echo "Pushing FreeBSD $$version:$$arch for $$dir"; \
			if grep -q "^$$version:$$arch$$" $$dir/RELEASES; then \
					echo "Pushing FreeBSD $$version:$$arch for $$dir"; \
					IMGNAME=$$(echo $$dir | sed 's|/|-|g') ; \
					podman push ${DOMAIN}/${ORG}/${IMGBASE}-$$IMGNAME-$$arch:$$version ;\
			fi; \
		  done; \
		done; \
	done

manifestmerge: push
	@for version in $(FREEBSD_VERSIONS); do \
		for dir in $(DIR); do \
			IMGNAME=$$(echo $$dir | sed 's|/|-|g') ; \
			podman manifest rm ${DOMAIN}/${ORG}/${IMGBASE}-$$IMGNAME:$$version | true ; \
			podman manifest create ${DOMAIN}/${ORG}/${IMGBASE}-$$IMGNAME:$$version ; \
			for arch in $(ARCH); do \
				COUNT=$$(podman search --list-tags ${DOMAIN}/${ORG}/${IMGBASE}-$$IMGNAME-$$arch  2>/dev/null | grep $$version | wc -l ); \
				if [ "$$COUNT" -eq 1 ]; then \
					echo "Adding $$arch image to ${DOMAIN}/${ORG}/${IMGBASE}-$$IMGNAME:$$version"; \
					podman manifest add ${DOMAIN}/${ORG}/${IMGBASE}-$$IMGNAME:$$version ${DOMAIN}/${ORG}/${IMGBASE}-$$IMGNAME-$$arch:$$version ;\
				fi; \
			done; \
		  	podman manifest push ${DOMAIN}/${ORG}/${IMGBASE}-$$IMGNAME:$$version ; \
		done; \
	done


manifestmerge-pkg: push-pkg
	@for version in $(FREEBSD_VERSIONS); do \
		podman manifest rm ${DOMAIN}/${ORG}/${IMGBASE}-pkg:$$version | true ; \
		podman manifest create ${DOMAIN}/${ORG}/${IMGBASE}-pkg:$$version ; \
		for arch in $(ARCH); do \
			COUNT=$$(podman search --list-tags ${DOMAIN}/${ORG}/${IMGBASE}-pkg-$$arch  2>/dev/null | grep $$version | wc -l ); \
			if [ "$$COUNT" -eq 1 ]; then \
				echo "Adding $$arch image to ${DOMAIN}/${ORG}/${IMGBASE}-pkg:$$version"; \
				podman manifest add ${DOMAIN}/${ORG}/${IMGBASE}-pkg:$$version ${DOMAIN}/${ORG}/${IMGBASE}-pkg-$$arch:$$version ;\
			fi; \
		done; \
		podman manifest push ${DOMAIN}/${ORG}/${IMGBASE}-pkg:$$version ; \
	done

manifestmerge-ports-tree: push-ports-tree
	@for version in $(FREEBSD_VERSIONS); do \
		podman manifest rm ${DOMAIN}/${ORG}/${IMGBASE}-ports-tree:$$version | true ; \
		podman manifest create ${DOMAIN}/${ORG}/${IMGBASE}-ports-tree:$$version ; \
		for arch in $(ARCH); do \
			COUNT=$$(podman search --list-tags ${DOMAIN}/${ORG}/${IMGBASE}-ports-tree-$$arch  2>/dev/null | grep $$version | wc -l ); \
			if [ "$$COUNT" -eq 1 ]; then \
				echo "Adding $$arch image to ${DOMAIN}/${ORG}/${IMGBASE}-ports-tree:$$version"; \
				podman manifest add ${DOMAIN}/${ORG}/${IMGBASE}-ports-tree:$$version ${DOMAIN}/${ORG}/${IMGBASE}-ports-tree-$$arch:$$version ;\
			fi; \
		done; \
		podman manifest push ${DOMAIN}/${ORG}/${IMGBASE}-ports-tree:$$version ; \
	done

.PHONY: help prebuild all build push build-ports-tree build-pkg push-pkg cleanup fetch-ports manifestmerge-pkg manifestmerge-ports-tree manifestmerge default

help:
	@echo "Available targets:"
	@echo "  all                  - Build all ports, pkg, and images, and push them"
	@echo "  build                - Build all images in DIR (default: all) for ARCH (default: all)"
	@echo "  push                 - Build and push images in DIR (default: all) for ARCH (default: all)"
	@echo "  fetch-ports          - Fetch the FreeBSD ports tree"
	@echo "  build-ports-tree     - Build the ports images"
	@echo "  push-ports-tree      - Push the ports images"
	@echo "  build-pkg            - Build the pkg images"
	@echo "  push-pkg             - Build and push pkg images"
	@echo "  manifestmerge        - Create and push multi-arch manifests for all images"
	@echo "  clean                - Remove temporary build artifacts"
	@echo "  prebuild             - Show build configuration"
	@echo "  help                 - Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  DIR              - Directory or list of directories to build (default: all)"
	@echo "  ARCH             - Architecture(s) to build (default: amd64 aarch64)"
	@echo "  FREEBSD_VERSIONS - FreeBSD version(s) to build (default: 15.0 14.3 14.2)"
	@echo "  DNS              - DNS server(s) to use (comma or space separated, optional)"
	@echo ""
	@echo "Example:"
	@echo "  make build DIR=java/openjdk21 ARCH=amd64"