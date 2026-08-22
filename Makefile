.PHONY: get format format-check analyze test example-get example-analyze example-platforms example-build-android rust-format rust-format-check rust-clippy rust-test rust-ci install-hooks pre-push ci

get:
	flutter pub get

format:
	dart format lib test example/lib

format-check:
	dart format --output=none --set-exit-if-changed lib test example/lib

analyze:
	flutter analyze

test:
	flutter test

example-get:
	cd example && flutter pub get

example-analyze: example-get
	cd example && flutter analyze lib

example-platforms:
	bash tool/bootstrap_example_platforms.sh

example-build-android: example-get example-platforms
	cd example && flutter build apk --debug

rust-format:
	cargo fmt --manifest-path rust/Cargo.toml

rust-format-check:
	cargo fmt --manifest-path rust/Cargo.toml --check

rust-clippy:
	cargo clippy --manifest-path rust/Cargo.toml --all-targets -- -D warnings

rust-test:
	cargo test --manifest-path rust/Cargo.toml

rust-ci: rust-format-check rust-clippy rust-test

install-hooks:
	bash tool/install_git_hooks.sh

pre-push:
	bash tool/pre_push.sh

ci: get format-check analyze test example-analyze rust-ci
