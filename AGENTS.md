**Tasks:** Every repository workflow is a mise task in `.mise-tasks/<group>/<name>.sh`, run as
`mise r <group>:<name>`. Each task is Bash with a `#MISE description="..."` header and
`set -euo pipefail`; declare dependencies with `#MISE depends=[...]`. Repository tooling is pinned in
`mise.toml`.

**Shell scripts:** Keep shell scripts compatible with macOS system Bash 3.2 so they also run on newer
Bash releases. Avoid Bash 4+ features such as associative arrays, `mapfile`, `${var,,}`, and `&>>`.
Use shfmt's default formatting; `dev:fmt` applies it.

**Checks:** After changes, run `mise run 'check:*'`. `check:changes` runs `dev:fmt` and, under
`CI=true`, fails when formatting differs from the checked-in tree.

**API reference:** Never commit an OpenAPI document or a hand-written endpoint page. The reference is
generated from the document the backend serves, referenced by URL in `docs.json`, so that it cannot
describe an API that is not deployed. Adding endpoint pages by hand reintroduces exactly the drift
that arrangement exists to prevent. Changes to the documented surface belong in atsback's protobuf
definitions.
