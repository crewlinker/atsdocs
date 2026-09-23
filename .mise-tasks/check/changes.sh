#!/usr/bin/env bash
#MISE description="Check formatted files are checked-in"
#MISE depends=["dev:fmt"]
set -euo pipefail

if [[ "${CI:-false}" == "true" ]]; then
	changes=$(git status --porcelain)
	if [[ -n "$changes" ]]; then
		echo "ERROR: Code is not up to date."
		echo "Run 'mise run dev:fmt' locally and commit the changes."
		echo
		echo "$changes"
		exit 1
	fi
fi
