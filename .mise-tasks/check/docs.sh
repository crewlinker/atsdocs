#!/usr/bin/env bash
#MISE description="Validate docs.json, the pages it references, and the published OpenAPI specification"
set -euo pipefail

# mint validate fetches the OpenAPI document from the URL in docs.json and parses it, so this is
# also the check that the backend is still publishing a specification we can build against. A
# hosted build performs the same fetch, which is why an unreachable or malformed specification has
# to fail here rather than at deploy time.
mint validate
mint broken-links

# mint validate reads the pages in docs.json but not the images it points at, so a logo, favicon,
# or social-card background can go missing without anything failing; the site then renders a broken
# image at a place nobody looks. Every local reference in docs.json starts with "/" and names a
# file, so check the ones that do.
missing=0
while read -r ref; do
	[[ -n "$ref" ]] || continue
	if [[ ! -f ".${ref}" ]]; then
		echo "ERROR: docs.json references ${ref}, which does not exist."
		missing=1
	fi
done <<EOF
$(grep -oE '"/[^"]+\.(svg|png|jpe?g|webp|gif|ico)"' docs.json | tr -d '"' | sort -u)
EOF

if [[ "$missing" != "0" ]]; then
	exit 1
fi
