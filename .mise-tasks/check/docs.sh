#!/usr/bin/env bash
#MISE description="Validate docs.json, the pages it references, and the published OpenAPI specification"
set -euo pipefail

# mint validate fetches the OpenAPI document from the URL in docs.json and parses it, so this is
# also the check that the backend is still publishing a specification we can build against. A
# hosted build performs the same fetch, which is why an unreachable or malformed specification has
# to fail here rather than at deploy time.
mint validate
mint broken-links
