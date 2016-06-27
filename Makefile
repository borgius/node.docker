VERSION ?= latest
LATEST_VERSION := $(shell sed -n '2p' versions)

ifeq ($(VERSION),latest)
	VERSION := $(LATEST_VERSION)
	TAG := latest
else
	TAG := $(VERSION)
endif

VERSION_PATH := version/${TAG}/
VERSION_ONBUILD_PATH := version/${TAG}-onbuild/
VERSION_DEVELOPMENT_PATH := version/${TAG}-development/

clean: clean-all-docker-images

run: build
	@docker run --rm -ti borgius/node-alpine:${TAG}

run-bash: build
	@docker run --rm -ti borgius/node-alpine:${TAG} /bin/login.sh

fetch-versions:
	@echo "latest" > versions
	wget https://nodejs.org/dist/ -O - 2>/dev/null | \
	grep "\">v" | \
	grep -v isaacs-manual | \
	sed -e 's/<a href="v\(.*\?\)\/.*/\1/' | \
	sed -e 's/\\/.*//' | \
	sort -t . -g -r >> versions

gen-version:
	@echo "Generating version dockerfiles: ${VERSION_PATH} ${VERSION_ONBUILD_PATH} ${VERSION_DEVELOPMENT_PATH}"
	@mkdir -p ${VERSION_PATH} ${VERSION_ONBUILD_PATH} ${VERSION_DEVELOPMENT_PATH}
	@cat Dockerfile | sed -e "s/NODE_VERSION=latest/NODE_VERSION=${VERSION}/" >${VERSION_PATH}/Dockerfile
	@echo "FROM borgius/node-alpine:${VERSION}" >${VERSION_ONBUILD_PATH}/Dockerfile
	@cat Dockerfile.onbuild >> ${VERSION_ONBUILD_PATH}/Dockerfile;
	@echo "FROM borgius/node-alpine:${VERSION}" >${VERSION_DEVELOPMENT_PATH}/Dockerfile
	@cat Dockerfile.development >> ${VERSION_DEVELOPMENT_PATH}/Dockerfile;

build: gen-version
	@echo "Building :${TAG} with ${VERSION} version"
	@docker build -t borgius/node-alpine:${TAG} -f ${VERSION_PATH}/Dockerfile .

push: build
	docker push borgius/node-alpine:${TAG}

gen-version-all:
	@for VERSION in $(shell cat versions); do \
		make VERSION=$$VERSION gen-version; \
	done;

build-all: fetch-versions
	@for VERSION in $(shell cat versions); do \
		make VERSION=$$VERSION build; \
	done;

push-all: fetch-versions
	@for VERSION in $(shell cat versions); do \
		make VERSION=$$VERSION push; \
	done;
