#!/usr/bin/env bash
#MISE description="Format shell and YAML files"
set -euo pipefail

find .mise-tasks -name '*.sh' -type f -print0 | xargs -0 shfmt -w
yamlfmt .github
