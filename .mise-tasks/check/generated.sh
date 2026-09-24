#!/usr/bin/env bash
#MISE description="Check no OpenAPI document or hand-written endpoint page is committed"
set -euo pipefail

# The API reference is generated at build time from the document the backend serves, which is what
# makes it unable to describe an API that is not deployed. Committing a copy of that document, or
# an endpoint page written by hand, reintroduces exactly the drift the arrangement prevents: the
# copy keeps rendering long after the backend has moved on, and nothing fails. Mintlify's editor
# and its agent will both happily produce either one, so the rule in AGENTS.md needs a check behind
# it rather than trust.

fail=0

# An OpenAPI document declares its version at the top level, as `openapi: 3.1.0` or `"openapi":
# "3.1.0"`. docs.json's `openapi` field holds a URL, not a version, so it does not match.
while read -r file; do
	[[ -n "$file" ]] || continue
	if grep -qE '^[[:space:]]*"?openapi"?[[:space:]]*:[[:space:]]*"?3\.' "$file"; then
		echo "ERROR: ${file} is a committed OpenAPI document."
		fail=1
	fi
done <<EOF
$(git ls-files '*.json' '*.yaml' '*.yml')
EOF

# A hand-written endpoint page binds itself to an operation with `openapi:` or `openapi-schema:` in
# its frontmatter. Prose about the reference, such as api-reference/overview.mdx, has neither.
while read -r file; do
	[[ -n "$file" ]] || continue
	frontmatter=$(awk 'NR==1 && $0!="---" {exit} NR>1 {if ($0=="---") exit; print}' "$file")
	if printf '%s\n' "$frontmatter" | grep -qE '^openapi(-schema)?:'; then
		echo "ERROR: ${file} describes an endpoint by hand."
		fail=1
	fi
done <<EOF
$(git ls-files '*.mdx')
EOF

if [[ "$fail" != "0" ]]; then
	echo
	echo "The reference is generated from the URL in docs.json. Changes to the documented surface"
	echo "belong in atsback's protobuf definitions, not here."
	exit 1
fi

echo "No committed OpenAPI document or hand-written endpoint page."
