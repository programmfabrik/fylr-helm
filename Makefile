EXTRA_ARGS?=""

# dep-install: installs dependencies needed to execute "ct"
dep-install:
	pip3 install yamale
	pip3 install --user yamllint

# install: installs the chart into the current selected Kubernetes cluster
install:
	ct install \
		--charts charts/* \
		--chart-dirs charts/ \
		--debug \
		${EXTRA_ARGS}

# lint: lints the chart
lint:
	ct lint \
		--charts charts/* \
		--chart-dirs charts/ \
		--chart-yaml-schema config/chart_schema.yaml \
		--lint-conf config/lintconf.yaml \
		--debug \
		${EXTRA_ARGS}
