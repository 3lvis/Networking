# The integration tests run against a local go-httpbin (https://github.com/mccutchen/go-httpbin),
# the same backend CI uses. `make test` spins one up in Docker, runs the suite, and tears it down.
# To iterate, run `make httpbin` once and then `swift test` as many times as you like.
# Requires Docker. The offline/faked test suites need no server.

HTTPBIN_CONTAINER := networking-go-httpbin
HTTPBIN_URL := http://127.0.0.1:8080

.PHONY: test httpbin httpbin-stop

test: httpbin
	@HTTPBIN_BASE_URL=$(HTTPBIN_URL) swift test; status=$$?; \
		$(MAKE) httpbin-stop; \
		exit $$status

httpbin:
	@docker rm -f $(HTTPBIN_CONTAINER) >/dev/null 2>&1 || true
	@docker run -d --name $(HTTPBIN_CONTAINER) -p 8080:8080 mccutchen/go-httpbin >/dev/null
	@for i in $$(seq 1 30); do \
		curl -sf $(HTTPBIN_URL)/get >/dev/null 2>&1 && echo "go-httpbin is up at $(HTTPBIN_URL)" && exit 0; \
		sleep 0.5; \
	done; \
	echo "go-httpbin did not become reachable at $(HTTPBIN_URL) within 15s"; \
	$(MAKE) httpbin-stop; \
	exit 1

httpbin-stop:
	@docker rm -f $(HTTPBIN_CONTAINER) >/dev/null 2>&1 || true
