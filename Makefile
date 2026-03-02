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
FREEBSD_VERSIONS := 15.0 14.3 14.2
ARCHITECTURES := amd64 aarch64
ARCH ?= $(ARCHITECTURES)
CURRENT_ARCHITECTURE ?= `uname -m`
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
	@echo "DIRS: ${DIRS}"
	@echo "DIR: ${DIR}"

ports:
.if !exists(ports/ports)
	git clone https://github.com/freebsd/freebsd-ports.git -b main ports/ports
.endif

clean:
	@rm -rf pkg/ports


build-ports: ports
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(ARCH); do \
			echo "Building FreeBSD $$version:$$arch for ports"; \
			if [ $$(echo "$$version < 15.0" | bc) -eq 1 ]; then \
				podman build --build-arg FREEBSD_RELEASE=$$version --build-arg ARCHITECTURE=$$arch --build-arg SRCIMAGENAME=freebsd-runtime -f ports/Containerfile -t ${DOMAIN}/${ORG}/${IMGBASE}-ports-$$arch:$$version ; \
			else \
				podman build --build-arg FREEBSD_RELEASE=$$version --build-arg ARCHITECTURE=$$arch -f ports/Containerfile -t ${DOMAIN}/${ORG}/${IMGBASE}-ports-$$arch:$$version ; \
			fi ; \
		done; \
	done

push-ports: build-ports
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(ARCH); do \
			echo "Pushing docker.io/cloudbsd/freebsd-build-ports-$$arch:$$version"; \
			podman push ${DOMAIN}/${ORG}/${IMGBASE}-ports-$$arch:$$version ;\
		done; \
	done

build-pkg: manifestmerge-ports
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(ARCH); do \
			echo "Building FreeBSD $$version:$$arch for pkg"; \
			podman build --build-arg FREEBSD_RELEASE=$$version --build-arg ARCHITECTURE=$$arch -f pkg/Containerfile -t ${DOMAIN}/${ORG}/${IMGBASE}-pkg-$$arch:$$version ;\
		done; \
	done

push-pkg: build-pkg
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(ARCH); do \
			echo "Pushing docker.io/cloudbsd/freebsd-build-pkg-$$arch:$$version"; \
			podman push ${DOMAIN}/${ORG}/${IMGBASE}-pkg-$$arch:$$version ;\
		done; \
	done

build: manifestmerge-ports manifestmerge-pkg
	@for version in $(FREEBSD_VERSIONS); do \
		for arch in $(ARCH); do \
		  for dir in $(DIR); do \
			if grep -q "^$$version:$$arch$$" $$dir/RELEASES; then \
				  echo "Building FreeBSD $$version:$$arch for $$dir"; \
				  IMGNAME=$$(echo $$dir | sed 's|/|-|g') ; \
				  podman build --build-arg FREEBSD_RELEASE=$$version --build-arg ARCHITECTURE=$$arch -f $$dir/Containerfile -t ${DOMAIN}/${ORG}/${IMGBASE}-$$IMGNAME-$$arch:$$version  ;\
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

manifestmerge-ports: push-ports
	@for version in $(FREEBSD_VERSIONS); do \
		podman manifest rm ${DOMAIN}/${ORG}/${IMGBASE}-ports:$$version | true ; \
		podman manifest create ${DOMAIN}/${ORG}/${IMGBASE}-ports:$$version ; \
		for arch in $(ARCH); do \
			COUNT=$$(podman search --list-tags ${DOMAIN}/${ORG}/${IMGBASE}-ports-$$arch  2>/dev/null | grep $$version | wc -l ); \
			if [ "$$COUNT" -eq 1 ]; then \
				echo "Adding $$arch image to ${DOMAIN}/${ORG}/${IMGBASE}-ports:$$version"; \
				podman manifest add ${DOMAIN}/${ORG}/${IMGBASE}-ports:$$version ${DOMAIN}/${ORG}/${IMGBASE}-ports-$$arch:$$version ;\
			fi; \
		done; \
		podman manifest push ${DOMAIN}/${ORG}/${IMGBASE}-ports:$$version ; \
	done

.PHONY: prebuild all build push build-ports build-pkg push-pkg cleanup ports manifestmerge-pkg manifestmerge-ports manifestmerge default