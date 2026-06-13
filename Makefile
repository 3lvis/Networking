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
	@until curl -sf $(HTTPBIN_URL)/get >/dev/null 2>&1; do sleep 0.2; done
	@echo "go-httpbin is up at $(HTTPBIN_URL)"

httpbin-stop:
	@docker rm -f $(HTTPBIN_CONTAINER) >/dev/null 2>&1 || true
