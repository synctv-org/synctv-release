SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

.DEFAULT_GOAL := validate

.PHONY: validate test manifests shellcheck actionlint

validate: test manifests shellcheck

test:
	ruby -Itest test/release_manifest_test.rb
	ruby -Itest test/release_notes_test.rb
	ruby -Itest test/web_ui_pin_test.rb

manifests:
	ruby script/manifest validate examples/release.yml
	@find releases -type f \( -name '*.yml' -o -name '*.yaml' \) -print0 | \
		xargs -0 -r -n1 ruby script/manifest validate

shellcheck:
	bash -n scripts/*.sh
	ruby -c script/verify-web-ui-pin

actionlint:
	go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7
