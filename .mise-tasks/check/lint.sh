#!/usr/bin/env bash
#MISE description="Lint shell scripts and GitHub Actions workflows"
#MISE depends=["dev:fmt"]
set -euo pipefail

find .mise-tasks -name '*.sh' -type f -print0 | xargs -0 shellcheck
actionlint
zizmor --offline --strict-collection .
