#!/usr/bin/env bash
#MISE description="Ask Mintlify to rebuild the published site, re-fetching the OpenAPI specification"
set -euo pipefail

# A hosted build downloads the OpenAPI document named in docs.json, so a rebuild is the only way a
# backend-side change to the specification reaches the site. Mintlify rebuilds on a push to the docs
# branch, and a backend deploy is not such a push, hence this call.
#
# The endpoint needs an admin API key, which Mintlify sells with its Pro and Enterprise plans; the
# dashboard shows admin keys as unavailable on ours. Skip rather than fail while that is true, so the
# schedule around this can still run deploy:watch, which needs no key and reports the drift this
# call would otherwise have prevented.
if [[ -z "${MINTLIFY_API_KEY:-}" ]]; then
	echo "MINTLIFY_API_KEY is not set, so there is no rebuild to trigger."
	echo "Mintlify's REST API needs a Pro or Enterprise plan. Without it the site rebuilds on a push"
	echo "to main, or from Update in the Mintlify dashboard."
	exit 0
fi

: "${MINTLIFY_PROJECT_ID:?MINTLIFY_PROJECT_ID must be set}"

status=$(curl --silent --show-error --fail-with-body \
	--request POST \
	--url "https://api.mintlify.com/v1/project/update/${MINTLIFY_PROJECT_ID}" \
	--header "Authorization: Bearer ${MINTLIFY_API_KEY}")

echo "Triggered Mintlify deployment: ${status}"
