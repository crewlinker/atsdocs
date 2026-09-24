# atsdocs

Sterndesk technical documentation, published with [Mintlify](https://mintlify.com).

## Working on the docs

Tooling is pinned in [`mise.toml`](mise.toml); `mise install` gets you the Mintlify CLI and the
linters.

```shell
mise run dev:run     # preview at http://localhost:3000
mise run 'check:*'   # what CI runs
```

You can also edit in [Mintlify's web editor](https://app.mintlify.com), which needs no checkout.
Publishing from there opens a pull request rather than writing to `main`, so editor changes run the
same checks as a `git push`. See [What the checks catch](#what-the-checks-catch).

## What the checks catch

`main` is protected: every change arrives by pull request and `checks.yml` has to pass. That applies
to the web editor too, which would otherwise merge straight into the deployment branch and publish
whatever it merged. Four things are enforced.

- **`check:docs`** runs `mint validate`, which fetches the OpenAPI document named in `docs.json` and
  parses it — the same fetch a hosted build does — then checks every page the navigation references
  exists. It also checks the images `docs.json` points at exist, which `mint validate` does not.
- **`check:urls`** builds the site and requires it to answer every URL the published site answers,
  taking `docs.sterndesk.com/sitemap.xml` as the contract. Mintlify derives a page's URL from its
  file path, so renaming, moving, or deleting a page silently 404s every reader holding the old
  link, and a build that does that is still internally valid. Moving a page on purpose costs one
  `redirects` entry in `docs.json`, which the check then accepts.
- **`check:generated`** fails if an OpenAPI document or a hand-written endpoint page is committed.
  See [How the API reference stays current](#how-the-api-reference-stays-current) for why that rule
  exists; the editor's agent will produce either one if asked to "document the API".
- **`check:lint`** and **`check:changes`** cover the shell scripts, the workflows, and formatting.

`check:docs` and `check:urls` both reach the public internet — for the OpenAPI document and for the
published sitemap. That is deliberate: a specification the build cannot fetch has to fail a pull
request here rather than a deploy.

## How the API reference stays current

The API reference is not written here and is not a copy of anything. [`docs.json`](docs.json) points
the **API reference** tab at the OpenAPI document the backend itself serves:

```
https://edge.test.sterndesk.com/api/openapi.yaml
```

That is staging. Production answers `{"code":"unimplemented"}` at the same path, because the release
carrying the handler has not shipped yet; pointing at it would fail every build. Switch the URL to
`https://edge.sterndesk.com/api/openapi.yaml` once a production release serves it. Until then the
reference can describe an operation staging has and production does not.

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
in GitHub Actions. Pull requests get a preview deployment from the same app, and
[`checks.yml`](.github/workflows/checks.yml) validates the build before merge.

This site is live at `docs.sterndesk.com`, and also at `atsdocs.mintlify.app`.

It is the **second deployment** in the `sterndesk` Mintlify organization. The first one builds
`basewarphq/recode-service` from its `docs/` directory — that is the Recode document-extraction
API, a different product — and it is live at `sterndesk.mintlify.app`. Do not repoint it at this
repository: an organization may hold several deployments, so this one gets its own. (The Enterprise
"multi-repo" feature is for combining repositories into a *single* site, which is not what we want
here.)

Its Git settings are `crewlinker/atsdocs`, branch `main`, subdirectory off, since `docs.json` lives
at the repository root.

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
two values this repository uses for its scheduled rebuild. Both come from the Mintlify dashboard.

Set them in this repository too. Until they exist, `sync_openapi.yml` fails on every run and the
reference is only as fresh as the last push, which defeats the point of the backstop:

```shell
gh variable set MINTLIFY_PROJECT_ID --repo crewlinker/atsdocs
gh secret   set MINTLIFY_API_KEY    --repo crewlinker/atsdocs
```
