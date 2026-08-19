.PHONY: get format format-check analyze test example-get example-analyze ci

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

ci: get format-check analyze test example-analyze
