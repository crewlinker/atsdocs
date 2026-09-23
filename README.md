# atsdocs

Sterndesk technical documentation, published with [Mintlify](https://mintlify.com).

## Working on the docs

Tooling is pinned in [`mise.toml`](mise.toml); `mise install` gets you the Mintlify CLI and the
linters.

```shell
mise run dev:run     # preview at http://localhost:3000
mise run 'check:*'   # what CI runs
```

## How the API reference stays current

The API reference is not written here and is not a copy of anything. [`docs.json`](docs.json) points
the **API reference** tab at the OpenAPI document the backend itself serves:

```
https://edge.test.sterndesk.com/api/openapi.yaml
```

atsback generates that document from its ConnectRPC service definitions and embeds it in the binary,
so it describes the API that is actually deployed. Every endpoint page here is generated from it. No
endpoint is described by hand, which is what makes it impossible for this site to document an
operation the API does not have.

Mintlify downloads the document **during each build**, not on each page view. So the reference is a
snapshot, and it is only as fresh as the last build. Two things keep that window small:

- **atsback triggers a rebuild when it deploys.** A backend release changes the published
  specification without pushing anything to this repository, so the deploy pipeline calls Mintlify's
  update endpoint. See [Triggering a rebuild from atsback](#triggering-a-rebuild-from-atsback).
- **[`sync_openapi.yml`](.github/workflows/sync_openapi.yml) rebuilds daily** as a backstop, in case
  that call is ever skipped or fails.

Because the specification is fetched rather than committed, drift is self-healing: any build, from
any cause, picks up the current document. A committed copy would stay wrong until somebody noticed.

`mise run check:docs` runs `mint validate`, which performs the same fetch a hosted build does. An
unreachable or malformed specification therefore fails a pull request here rather than a deploy.

## Deployment

Merging to `main` deploys the site. Mintlify's GitHub App watches this repository and builds the
configured branch; there is no deploy workflow in `.github/workflows` because the build does not run
in GitHub Actions. Configure the repository and branch under
[Git Settings](https://dashboard.mintlify.com/settings/deployment/git-settings) in the Mintlify
dashboard.

Pull requests get a preview deployment from the same app, and
[`checks.yml`](.github/workflows/checks.yml) validates the build before merge.

### Triggering a rebuild from atsback

Add this to atsback's `deploy_release.yml`, after the `deploy infra` step, so a production release
refreshes the reference:

```yaml
- name: refresh published API documentation
  run: |
    curl --silent --show-error --fail-with-body \
      --request POST \
      --url "https://api.mintlify.com/v1/project/update/${MINTLIFY_PROJECT_ID}" \
      --header "Authorization: Bearer ${MINTLIFY_API_KEY}"
  env:
    MINTLIFY_PROJECT_ID: ${{ vars.MINTLIFY_PROJECT_ID }}
    MINTLIFY_API_KEY: ${{ secrets.MINTLIFY_API_KEY }}
```

It needs `MINTLIFY_PROJECT_ID` as a repository variable and `MINTLIFY_API_KEY` as a secret, the same
two values this repository uses for its scheduled rebuild.
