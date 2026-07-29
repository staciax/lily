# Copyright © 2025-2026 Apple Inc. and the container project authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   https://www.apache.org/licenses/LICENSE-2.0
#
# See LICENSE for license information.
# SPDX-License-Identifier: Apache-2.0
#
#
# This file is part of the Lily open source project.
# Modifications Copyright © 2026 STACiA and the Lily project authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   https://www.apache.org/licenses/LICENSE-2.0
#
# See LICENSE for license information.
# SPDX-License-Identifier: Apache-2.0

# Version and build configuration variables
BUILD_CONFIGURATION ?= debug
WARNINGS_AS_ERRORS ?= true
SWIFT_CONFIGURATION := $(if $(filter-out false,$(WARNINGS_AS_ERRORS)),-Xswiftc -warnings-as-errors) -Xswiftc -enable-testing
COVERAGE_FLAG ?=

export RELEASE_VERSION ?= $(shell git describe --tags --always 2>/dev/null || echo "0.1.0")
export GIT_COMMIT := $(shell git rev-parse HEAD 2>/dev/null || echo "unknown")

SWIFT ?= swift
SWIFT_BUILD = $(SWIFT) build -c $(BUILD_CONFIGURATION) $(SWIFT_CONFIGURATION)
ROOT_DIR := $(shell git rev-parse --show-toplevel 2>/dev/null || pwd)

COV_REPORT_FILE = $(ROOT_DIR)/code-coverage-report
COVERAGE_OUTPUT_DIR := $(ROOT_DIR)/coverage-reports

.DEFAULT_GOAL := all

.PHONY: all
all: build test check

.PHONY: build
build:
	@echo Building Lily binaries...
	@$(SWIFT) --version
	@$(SWIFT_BUILD)

.PHONY: build-tests
build-tests:
	@echo Building Lily binaries and tests...
	@$(SWIFT) --version
	@$(SWIFT_BUILD) --build-tests $(COVERAGE_FLAG)

.PHONY: test
test: build-tests
	@echo Running tests...
	@$(SWIFT) test --skip-build -c $(BUILD_CONFIGURATION) $(SWIFT_CONFIGURATION)

.PHONY: release
release: BUILD_CONFIGURATION = release
release: all

.PHONY: benchmark
benchmark:
	@echo "Running performance benchmarks..."
	@ENABLE_LILY_BENCHMARKS=1 $(SWIFT) package --disable-sandbox benchmark

.PHONY: fmt format
fmt format: swift-fmt

.PHONY: check lint
check lint: swift-fmt-check

SWIFT_SRC = $(shell find . -type f -name '*.swift' -not -path "*/.*" -not -path "*/Fixtures/*" -not -path "*/checkouts/*")

.PHONY: swift-fmt
swift-fmt:
	@echo Applying the standard code formatting...
	@$(SWIFT) format --recursive --configuration .swift-format -i $(SWIFT_SRC)

.PHONY: swift-fmt-check
swift-fmt-check:
	@echo Checking code formatting...
	@$(SWIFT) format lint --recursive --strict --configuration .swift-format-nolint $(SWIFT_SRC)

.PHONY: check-upstream
check-upstream:
	@echo Checking upstream sync...
	@uv run scripts/check-swift-log-stream-handler.py

.PHONY: test-coverage
test-coverage: COVERAGE_FLAG = --enable-code-coverage
test-coverage: build-tests
	@echo Running unit test coverage...
	@mkdir -p $(COVERAGE_OUTPUT_DIR)/unit
	@$(SWIFT) test --skip-build --enable-code-coverage -c $(BUILD_CONFIGURATION) $(SWIFT_CONFIGURATION)

.PHONY: clean
clean:
	@echo Cleaning build files...
	@rm -rf .build/
	@rm -f $(COV_REPORT_FILE)
	@rm -rf $(COVERAGE_OUTPUT_DIR)
	@$(SWIFT) package clean
