#!/usr/bin/env bash
#MISE description="Report when the published reference no longer matches the specification the backend serves"
set -euo pipefail

# Mintlify downloads the OpenAPI document during a build, so the reference is a snapshot and a
# backend release does not refresh it. deploy:trigger is the intended remedy, but it needs a Mintlify
# plan this organization does not have, which leaves the reference able to drift silently. So watch
# the published site from outside instead and say so when it no longer matches the backend. This
# reports rather than repairs: a rebuild needs a push to main or the dashboard's Update button.

# gh is not pinned in mise.toml the way the linters are: mise cannot install it here (its GitHub
# attestation check fails), and it is already present wherever this runs, like curl and git. Say so
# plainly rather than failing later inside report().
if ! command -v gh >/dev/null; then
	echo "ERROR: deploy:watch files its reports as GitHub issues and needs the gh CLI."
	exit 1
fi

: "${GH_REPO:=crewlinker/atsdocs}"
export GH_REPO

site=${DOCS_SITE_URL:-https://docs.sterndesk.com}
spec=${STERNDESK_SPEC_URL:-https://edge.sterndesk.com/api/openapi.yaml}

# One open issue per condition. The label is what makes a daily schedule report a standing problem
# once instead of filing it again every morning.
report() {
	label=$1
	title=$2
	body=$3

	if [[ -n "$(gh issue list --label "$label" --state open --limit 1 --json number --jq '.[].number')" ]]; then
		echo "Already reported: ${title}"
		return 0
	fi

	gh label create "$label" --description "Opened by deploy:watch" --force >/dev/null
	gh issue create --label "$label" --title "$title" --body "$body"
}

# Every operation in the specification becomes one generated page, and the only other pages under
# the reference are the prose committed here. If those numbers disagree, the site was built from an
# older specification than the backend serves now.
operations=$(curl --silent --show-error --fail-with-body --location --max-time 60 "$spec" |
	grep -cE '^      operationId:' || true)
prose=$(git ls-files 'api-reference/*.mdx' | grep -c . || true)
published=$(curl --silent --show-error --fail-with-body --location --max-time 60 "$site/sitemap.xml" |
	grep -o '<loc>[^<]*</loc>' | grep -c '/api-reference/' || true)
generated=$((published - prose))

echo "Specification describes ${operations} operations; ${site} publishes ${generated}."

if [[ "$operations" == "0" ]]; then
	echo "ERROR: found no operations in ${spec}, so the comparison means nothing."
	exit 1
fi

if [[ "$generated" != "$operations" ]]; then
	report "stale-reference" "The published API reference is out of date" "\
\`${spec}\` describes **${operations}** operations but ${site} publishes **${generated}** endpoint
pages, so the site was built from an older specification than the backend serves now.

Mintlify downloads the document during a build, and a backend release is not a build. Rebuild by
pushing to \`main\` or with **Update** in the Mintlify dashboard. Close this issue once the counts
agree; deploy:watch will reopen the report if they diverge again."
else
	echo "The published reference matches the specification."
fi
