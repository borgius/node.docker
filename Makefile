VERSION ?= latest
LATEST_VERSION := $(shell sed -n '2p' versions)
REPO_PATH := $(shell pwd)

ifeq ($(VERSION),latest)
	VERSION := $(LATEST_VERSION)
	TAG ?= latest
else
	TAG ?= $(VERSION)
endif

VERSION_PATH := version/${VERSION}

clean: clean-all-docker-images

run: build
	@docker run --rm -ti borgius/node-alpine:${TAG}

run-bash: build
	@docker run --rm -ti borgius/node-alpine:${TAG} /bin/login.sh

fetch-versions:
	@echo "latest" > ./versions
	@wget https://nodejs.org/dist/ -O - 2>/dev/null | \
	grep "/\">v" | grep -v isaacs-manual | \
	sed -e 's/<a href="v\(.*\)\/".*/\1/' | \
	sort -t . -g -r | head -n 10 >> ./versions
	@cat versions

generate-version:
	@echo "Generating version dockerfiles: ${VERSION_PATH}"
	@mkdir -p ${VERSION_PATH}
	@cat src/Dockerfile | sed -e "s/NODE_VERSION=latest/NODE_VERSION=${VERSION}/" >${VERSION_PATH}/Dockerfile
	@echo "FROM borgius/node-alpine:${VERSION}" >${VERSION_PATH}/Dockerfile.onbuild;
	@cat src/Dockerfile.onbuild >> ${VERSION_PATH}/Dockerfile.onbuild;
	@echo "FROM borgius/node-alpine:${VERSION}" >${VERSION_PATH}/Dockerfile.development;
	@cat src/Dockerfile.development >> ${VERSION_PATH}/Dockerfile.development;
ifeq ($(VERSION),latest)
	@cp src/.travis.latest.yml ${VERSION_PATH}/.travis.yml;
else
	@cp src/.travis.yml ${VERSION_PATH}/.travis.yml;
endif



generate-tag-version:
	@rm -fR ${VERSION_PATH} && \
	mkdir -p ${VERSION_PATH} && \
	cd ${VERSION_PATH} && \
	git init && \
	git remote add origin git@github.com:borgius/node.docker.git && \
	{ \
		git fetch origin ${VERSION_PATH} && \
			git checkout ${VERSION_PATH} || \
			git checkout -b ${VERSION_PATH}; \
	} && \
	{ \
		make -C ${REPO_PATH} VERSION=${VERSION} generate-version && \
		git diff-index --quiet HEAD -- && { \
			echo "${VERSION}: No diff spotted"; \
		} || { \
			echo "${VERSION}: Uploading changes to GitHub" && \
			git add . && \
			git commit -m ${VERSION_PATH} && \
			git push origin ${VERSION_PATH} --force; \
		}; \
	} && \
	{ echo "${VERSION}: Finished" && exit 0; } || \
	{ echo "${VERSION}: Finished with some errors, please check." && exit 1; }


build: generate-version
	@echo "Building :${TAG} with ${VERSION} version"
	@echo "build -t borgius/node-alpine:${TAG} ${VERSION_PATH}"
	@docker build -t borgius/node-alpine:${TAG} -f ${VERSION_PATH}/Dockerfile .

build-tags: generate-tag-version
	@echo "Building :${TAG} with ${VERSION} version"
	@docker build -t borgius/node-alpine:${VERSION} -f ${VERSION_PATH}/Dockerfile .
	@docker build -t borgius/node-alpine:${VERSION}-dev -f ${VERSION_PATH}/Dockerfile.development .
	@docker build -t borgius/node-alpine:${VERSION}-onbuild -f ${VERSION_PATH}/Dockerfile.onbuild .

push: build
	docker push borgius/node-alpine:${TAG}

push-tags: build-tags
	docker push borgius/node-alpine:${VERSION}
	docker push borgius/node-alpine:${VERSION}-dev
	docker push borgius/node-alpine:${VERSION}-onbuild

generate-version-all: fetch-versions
	@for VERSION in $(shell cat versions); do \
		make VERSION=$$VERSION generate-version; \
	done;

generate-tag-version-all: fetch-versions
	@for VERSION in $(shell cat versions); do \
		make VERSION=$$VERSION generate-tag-version; \
	done;

build-all: fetch-versions
	@for VERSION in $(shell cat versions); do \
		make VERSION=$$VERSION build; \
	done;

build-all-tags: fetch-versions
	@for VERSION in $(shell cat versions); do \
		make VERSION=$$VERSION build-tags; \
	done;


push-all: fetch-versions
	@for VERSION in $(shell cat versions); do \
		make VERSION=$$VERSION push; \
	done;

push-all-tags: fetch-versions
	@for VERSION in $(shell cat versions); do \
		make VERSION=$$VERSION push-tags; \
	done;

deploy: generate-tag-version-all
