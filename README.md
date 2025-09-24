# Windows CA smoke reusable workflow

This repo hosts a reusable GitHub Actions workflow that provisions a temporary Windows root certificate, exercises your HTTPS client both before and after trusting that root, and cleans up any state that was created. The workflow mirrors the scripts we already ship (PowerShell CA helper + Node HTTPS server) so repos only need to wire in their language-specific test commands.

## How to call the workflow

Reference the workflow from another repo with a standard workflow wrapper. The parameters below cover the Rust, CLI, and Python SDK cases that previously duplicated logic.

### Rust crates (`kittycad.rs`, `cli`)

```yaml
name: win-ca-smoke

on:
  pull_request:
  push:
    branches: [ main, master ]

jobs:
  smoke:
    strategy:
      fail-fast: false
      matrix:
        node: [20, 22]
    uses: kittycad/gh-action-win-ca/.github/workflows/win-ca-smoke.yml@main
    with:
      node-version: ${{ matrix.node }}
      setup-rust: true
      pre-test-command: cargo test --test win_ca_smoke -- --nocapture
      post-test-command: cargo test --test win_ca_smoke -- --nocapture
    env:
      RUST_BACKTRACE: '1'
      SMOKE_URL: 'https://127.0.0.1:4443/' # only needed for the CLI binary
```

### Python SDK (`kittycad.py`)

```yaml
jobs:
  smoke:
    uses: kittycad/gh-action-win-ca/.github/workflows/win-ca-smoke.yml@main
    with:
      setup-python: true
      install-command: |
        uv sync --extra dev
      pre-test-command: uv run pytest kittycad/tests/test_win_ca_smoke.py --maxfail=1 --disable-warnings -q
      post-test-command: uv run pytest kittycad/tests/test_win_ca_smoke.py --maxfail=1 --disable-warnings -q
    env:
      WIN_CA_HOST: 'https://127.0.0.1:4443'
```

### MCP service (`zoo-mcp`)

```yaml
jobs:
  smoke:
    uses: kittycad/gh-action-win-ca/.github/workflows/win-ca-smoke.yml@main
    with:
      setup-python: true
      python-version-file: pyproject.toml
      install-command: uv sync --dev
      pre-test-command: uv run pytest tests/test_win_ca_smoke.py --maxfail=1 --disable-warnings -q
      post-test-command: uv run pytest tests/test_win_ca_smoke.py --maxfail=1 --disable-warnings -q
```

## Inputs reference

| input | default | notes |
| --- | --- | --- |
| `node-version` | `22` | Accepts a matrix value from the caller. |
| `setup-rust` | `false` | Installs `dtolnay/rust-toolchain@stable` and `Swatinem/rust-cache@v2` when true. |
| `setup-python` | `false` | Installs Python via `actions/setup-python@v6` and `astral-sh/setup-uv@v6`. |
| `python-version` / `python-version-file` | `3.13` / empty | Use the file form for repos that pin the version in `pyproject.toml`. |
| `install-command` | _empty_ | Optional dependency bootstrap (runs in PowerShell, within `working-directory`). |
| `pre-test-command`, `post-test-command` | _required_ | Commands that exercise the HTTPS client before/after trust. |
| `pre-step-extra-env` | `{ "WIN_CA_EXPECT_SUCCESS": "0" }` | Injects extra env vars for the pre-trust run; parsed as JSON. |
| `post-step-extra-env` | `{ "WIN_CA_EXPECT_SUCCESS": "1" }` | Same idea for the post-trust run. Override if your tests need different flags. |
| `working-directory` | `.` | Directory that contains `scripts/win/create-local-ca.ps1` and your tests. |
| `pfx-path`, `pfx-password` | `servercert.pfx`, `pass` | Customize if you want to stash certs elsewhere. |

Every command step inherits `WIN_CA_SMOKE=1` and `NODE_EXTRA_CA_CERTS` pointing at the generated `root.pem`, so there is no need to wire those manually. You can still set additional `env:` keys on the calling job (e.g., `SMOKE_ATTEMPTS`) and they will propagate to both the pre- and post-trust runs.

## Expectations on the target repo

- `scripts/win/create-local-ca.ps1` and `scripts/https-server.mjs` must exist relative to the repository root.
- Tests should honor `WIN_CA_SMOKE=1` to guard Windows-only execution.
- Anything written to disk during the run should live under the working directory so the cleanup step can delete `root.pem`, `root.cer`, and the generated PFX.

That is everything: wire this workflow in and delete the duplicated YAML in each repo. The only variance left is the test command you want to run.
