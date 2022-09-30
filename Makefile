EXTRA_ARGS?=""

.PHONY: all
all: lint

# lint: lints the chart
.PHONY: lint
lint: lint-execserver lint-fylr

# test: installs the charts and runs tests
.PHONY: test
test: test-execserver test-fylr

# install: installs the charts
.PHONY: install
install: install-execserver install-fylr

# dep-install: installs dependencies needed to execute "ct"
dep-install:
	pip3 install yamale
	pip3 install --user yamllint

# lint the execserver chart
lint-execserver:
	ct lint \
		--charts charts/execserver \
		--chart-dirs charts/ \
		--chart-yaml-schema config/chart_schema.yaml \
		--lint-conf config/lintconf.yaml \
		--debug \
		${EXTRA_ARGS}

# lint the fylr chart
lint-fylr:
	ct lint \
		--charts charts/fylr \
		--chart-dirs charts/fylr \
		--chart-yaml-schema config/chart_schema.yaml \
		--lint-conf config/lintconf.yaml \
		--debug \
		${EXTRA_ARGS}

# test-execserver test-installs the execserver and waits for the tests to complete
test-execserver:
	ct install \
		--charts charts/execserver \
		--chart-dirs charts/ \
		--debug \
		${EXTRA_ARGS}

# test-fylr test-installs the fylr and waits for the tests to complete
test-fylr:
	ct install \
		--charts charts/fylr \
		--chart-dirs charts/ \
		--debug \
		${EXTRA_ARGS}

# install-execserver: installs the execserver
install-execserver:
	helm install execserver charts/execserver

# install-fylr: installs the fylr
install-fylr:
	helm install fylr charts/fylr
