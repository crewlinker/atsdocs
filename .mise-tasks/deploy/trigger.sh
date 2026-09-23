#!/usr/bin/env bash
#MISE description="Ask Mintlify to rebuild the published site, re-fetching the OpenAPI specification"
set -euo pipefail

: "${MINTLIFY_PROJECT_ID:?MINTLIFY_PROJECT_ID must be set}"
: "${MINTLIFY_API_KEY:?MINTLIFY_API_KEY must be set}"

# A hosted build downloads the OpenAPI document named in docs.json, so a rebuild is the only way a
# backend-side change to the specification reaches the site. Mintlify rebuilds on a push to the
# docs branch, and a backend deploy is not such a push, hence this call.
status=$(curl --silent --show-error --fail-with-body \
	--request POST \
	--url "https://api.mintlify.com/v1/project/update/${MINTLIFY_PROJECT_ID}" \
	--header "Authorization: Bearer ${MINTLIFY_API_KEY}")

echo "Triggered Mintlify deployment: ${status}"
