# SPDX-License-Identifier: Apache-2.0
IMAGE_NAME ?= fpga-suite_080823:y0.68-v5.050
DOCKER ?= docker
THIS_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
REPO_ROOT := $(abspath $(THIS_DIR)/../..)
WIN_DOCKER := $(findstring .exe,$(notdir $(DOCKER)))
HOST_REPO_ROOT := $(if $(WIN_DOCKER),$(shell wslpath -w "$(REPO_ROOT)"),$(REPO_ROOT))

.PHONY: all image local
all:
	$(DOCKER) run --rm --network none --user $(shell id -u):$(shell id -g) \
		--mount "type=bind,source=$(HOST_REPO_ROOT),target=/work" \
		--tmpfs /build:rw,size=2G,exec,mode=1777 \
		-w /work/syn/yosys \
		-e SYNTH_IMAGE=$(IMAGE_NAME) \
		-e SYNTH_IMAGE_ID="$(shell $(DOCKER) image inspect --format '{{.Id}}' $(IMAGE_NAME))" \
		$(IMAGE_NAME) python3 run.py

image:
	$(MAKE) -f $(THIS_DIR)/../dockerfile/make_env build DOCKER=$(DOCKER) IMAGE_NAME=$(IMAGE_NAME)

local:
	cd $(THIS_DIR) && python3 run.py
