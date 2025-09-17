iosevka = https://github.com/be5invis/Iosevka/releases/download/v33.2.7/PkgWebFont-IosevkaSS13-33.2.7.zip
inter = https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip

.PHONY: build
build: build-frontend
	gleam build

.PHONY: check
check: check-frontend
	gleam check

.PHONY: watch
watch: .restart
	watchexec --clear --quiet --restart --stop-signal INT --stop-timeout 150ms --watch .restart make run

.restart:
	touch .restart

.PHONY: run
run: build-frontend
	gleam run

.PHONY: clean
clean: clean-pkgs
	gleam clean

.PHONY: clean-manifests
clean-manifests: clean-pkgs-manifests
	rm manifest.toml

.PHONY: clean-pkgs
clean-pkgs:
	find pkgs -maxdepth 2 -name gleam.toml -execdir gleam clean \;

.PHONY: clean-pkgs-manifests
clean-pkgs-manifests:
	find pkgs -maxdepth 2 -name manifest.toml -delete

.PHONY: watch-check
watch-check: 
	watchexec --exts gleam make check

.PHONY: build-frontend
build-frontend: assets/Inter assets/Iosevka
	mkdir -p priv/static
	cd pkgs/frontend && gleam build
	cp assets/favicon.ico priv/static/favicon.ico

	esbuild --bundle --format=esm --log-level=error --loader:.ttf=file --loader:.woff2=file --external:tailwindcss --outdir=priv/static assets/app.js assets/app.css

	tailwindcss --minify --input priv/static/app.css --output priv/static/build.css
	mv priv/static/build.css priv/static/app.css

.PHONY: check-frontend
check-frontend:
	cd pkgs/frontend && gleam check

assets/Iosevka:
	mkdir assets/Iosevka
	curl --silent -L $(iosevka) | bsdtar -C assets/Iosevka -xf-

assets/Inter:
	curl --silent -L $(inter) | bsdtar -C assets -s /^web/Inter/ -xf- web

.PHONY: commit
commit_message = $(shell echo $(message) | xargs)
commit: message ?= $(shell git diff --name-only --cached | xargs basename)
commit:
	test -n "$(commit_message)"
	git commit -m "$(commit_message)"

.PHONY: push
push: commit
	git push
