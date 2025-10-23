define github_release
https://github.com/$(1)/releases/download/$(2)
endef

iosevka = $(call github_release,be5invis/Iosevka,v33.2.7/PkgWebFont-IosevkaSS13-33.2.7.zip)
inter = $(call github_release,rsms/inter,v4.1/Inter-4.1.zip)

watch := watchexec --clear --quiet --restart --stop-signal INT --stop-timeout 150ms --watch .restart

.PHONY: build
build: build-frontend
	gleam build

.PHONY: dist
dist: build-frontend
	gleam export erlang-shipment

.PHONY: run-server
run-server: build-frontend
	gleam run

.PHONY: watch-server
watch-server: .restart
	$(watch) make run-server --no-print-directory

.PHONY: run-command-proxy
run-command-proxy:
	go run -C apps/command-proxy ./cmd/command-proxy

.PHONY: watch-command-proxy
watch-command-proxy: .restart
	$(watch) make run-command-proxy --no-print-directory

.restart:
	touch .restart

.PHONY: check
check:
	@gleam check

.PHONY: tests
tests:
	@gleam test

.PHONY: tests-debug
tests-debug:
	@DEBUG=1 make tests

.PHONY: snapshot
snapshot:
	gleam run -m birdie

.PHONY: watch-tests
watch-tests:
	@watchexec --quiet --exts gleam,yaml,erl,js,mjs make tests --no-print-directory

.PHONY: watch-tests-debug
watch-tests-debug:
	@DEBUG=1 make watch-tests --no-print-directory

.PHONY: update
update: update-pkgs
	gleam update

.PHONY: update-pkgs
update-pkgs:
	find pkgs -maxdepth 2 -name gleam.toml -execdir gleam update \;

.PHONY: clean
clean: clean-pkgs
	gleam clean

.PHONY: clean-pkgs
clean-pkgs:
	find pkgs -maxdepth 2 -name gleam.toml -execdir gleam clean \;

.PHONY: clean-manifests
clean-manifests: clean-pkgs-manifests
	rm manifest.toml

.PHONY: clean-pkgs-manifests
clean-pkgs-manifests:
	find pkgs -maxdepth 2 -name manifest.toml -delete

.PHONY: build-frontend
build-frontend: assets/Inter assets/Iosevka
	mkdir -p priv/static
	cd pkgs/frontend && gleam build
	cp assets/favicon.ico priv/static/favicon.ico
	esbuild --bundle --format=esm --log-level=error --loader:.ttf=file --loader:.woff2=file \
	--external:tailwindcss --outdir=priv/static assets/app.js assets/app.css
	tailwindcss --minify --input priv/static/app.css --output priv/static/build.css
	mv priv/static/build.css priv/static/app.css

assets/Iosevka:
	mkdir assets/Iosevka
	curl --silent -L $(iosevka) | bsdtar -C assets/Iosevka -xf-

assets/Inter:
	curl --silent -L $(inter) | bsdtar -C assets -s /^web/Inter/ -xf- web

.PHONY: commit
commit: commit_message ?= $(shell git diff --name-only --cached | xargs basename)
commit:
	test -n "$(commit_message)"
	git commit -m "$(commit_message)"

.PHONY: push
push: commit
	git push
