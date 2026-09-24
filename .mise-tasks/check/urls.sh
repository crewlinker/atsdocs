#!/usr/bin/env bash
#MISE description="Check this build still answers every URL the published site answers"
set -euo pipefail

# Mintlify derives a page's URL from its file path, and the web editor lets a contributor rename,
# move, or delete a page without ever seeing the address that changes. `mint validate` does not
# notice: the new build is internally consistent, it just no longer answers where the old one did,
# so the failure only shows up as a 404 for readers holding the old link. Treat the published
# sitemap as the contract instead, and require this build to honour every URL in it. Moving a page
# on purpose stays possible and costs one `redirects` entry in docs.json, which the preview serves
# and this check then accepts.

site=${DOCS_SITE_URL:-https://docs.sterndesk.com}
port=${DOCS_PREVIEW_PORT:-3999}

log=$(mktemp)
paths=$(mktemp)
preview=""

cleanup() {
	if [[ -n "$preview" ]]; then
		kill "$preview" 2>/dev/null || true
	fi
	rm -f "$log" "$paths"
	return 0
}
trap cleanup EXIT

# The sitemap lists absolute URLs, one per <loc>. Strip the origin to get the path a local preview
# has to answer; the home page reduces to an empty string, so name it "/" again.
curl --silent --show-error --fail-with-body --location --max-time 60 "$site/sitemap.xml" |
	tr '<' '\n' | sed -n 's|^loc>||p' | sed "s|^${site}||" | sed 's|^$|/|' | sort -u >"$paths"

published=$(wc -l <"$paths" | tr -d ' ')
if [[ "$published" == "0" ]]; then
	echo "ERROR: ${site}/sitemap.xml listed no pages, so there is nothing to compare against."
	exit 1
fi
echo "Comparing this build against ${published} URLs published at ${site}"

mint dev --port "$port" >"$log" 2>&1 &
preview=$!

ready=false
for _ in $(seq 1 90); do
	if curl --silent --output /dev/null --max-time 5 "http://localhost:${port}/"; then
		ready=true
		break
	fi
	sleep 2
done

if [[ "$ready" != "true" ]]; then
	echo "ERROR: the local preview never started on port ${port}."
	cat "$log"
	exit 1
fi

broken=""
while read -r path; do
	code=$(curl --silent --location --output /dev/null --write-out '%{http_code}' \
		--max-time 30 "http://localhost:${port}${path}")
	if [[ "$code" != "200" ]]; then
		broken="${broken}${path} (${code})"$'\n'
	fi
done <"$paths"

if [[ -n "$broken" ]]; then
	echo "ERROR: this build no longer serves URLs that ${site} serves today:"
	printf '  %s\n' "$broken" | sed '/^  $/d'
	echo "Renaming, moving, or deleting a page changes its URL. Keep the published address working"
	echo "by adding a redirect to docs.json:"
	echo '  "redirects": [{ "source": "/old/path", "destination": "/new/path" }]'
	exit 1
fi

echo "All ${published} published URLs still resolve."
