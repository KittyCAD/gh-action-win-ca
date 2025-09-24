# Windows CA smoke reusable workflow

This repo hosts a reusable GitHub Actions workflow that provisions a temporary Windows root certificate, exercises your HTTPS client both before and after trusting that root, and cleans up any state that was created. The workflow mirrors the scripts we already ship (PowerShell CA helper + Node HTTPS server) so repos only need to wire in their language-specific smoke tests.

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

### TypeScript SDK (`kittycad.ts`)

```yaml
jobs:
  smoke:
    strategy:
      fail-fast: false
      matrix:
        node: [20, 22]
    uses: kittycad/gh-action-win-ca/.github/workflows/win-ca-smoke.yml@main
    with:
      node-version: ${{ matrix.node }}
      install-command: |
        npm install --frozen-lockfile
        npm run build
      pre-test-command: node scripts/win-ca-smoke.mjs
      post-test-command: node scripts/win-ca-smoke.mjs
    env:
      SMOKE_URL: 'https://127.0.0.1:4443/'
```

## Inputs reference

| input | default | notes |
| --- | --- | --- |
| `node-version` | `22` | Accepts a matrix value from the caller. |
| `setup-rust` | `false` | Installs `dtolnay/rust-toolchain@stable` plus the cargo cache when true. |
| `setup-python` | `false` | Installs Python via `actions/setup-python@v6` and `astral-sh/setup-uv@v6`. |
| `python-version` / `python-version-file` | `3.13` / empty | Pick one; the file form reads from `pyproject.toml`. |
| `install-command` | _empty_ | Optional dependency bootstrap (runs inside PowerShell). |
| `ensure-helper-scripts` | `true` | When true, downloads default helper scripts if they are missing. |
| `helper-ca-relative-path` / `helper-server-relative-path` | defaults above | Override remote paths used when fetching helper scripts. |
| `pre-test-command`, `post-test-command` | _required_ | Commands that must fail before trust and pass after. |
| `pre-step-extra-env`, `post-step-extra-env` | JSON | Additional env vars applied to each test invocation. |
| `working-directory` | `.` | Location of your scripts/tests relative to repo root. |
| `ca-script-path`, `server-script` | `./scripts/win/create-local-ca.ps1`, `./scripts/https-server.mjs` | Override to reuse custom helpers. |
| `pfx-path`, `pfx-password` | `servercert.pfx`, `pass` | File name and password handed to the PowerShell helper. |
| `server-port`, `ready-timeout-seconds` | `4443`, `30` | Tune the HTTPS server health probe. |
| `expected-pre-failure-message` | text | Error surfaced when the pre-trust command succeeds unexpectedly. |
| `helper-repo` | `kittycad/gh-action-win-ca` | Repository hosting the default helper scripts. |
| `helper-ref` | `main` | Git ref pulled from `helper-repo` when scripts are missing locally. |

Every command step inherits `WIN_CA_SMOKE=1` and `NODE_EXTRA_CA_CERTS` pointing at the generated `root.pem`, so there is no need to wire those manually. You can still set extra `env:` keys on the calling job (for example `SMOKE_ATTEMPTS`) and they will propagate to both the pre- and post-trust runs.

## Expectations on the target repo

- Helper scripts are downloaded automatically when missing, so vendoring `scripts/win/create-local-ca.ps1` and `scripts/https-server.mjs` is optional.
- Tests should honor `WIN_CA_SMOKE=1` to guard Windows-only execution.
- Anything written to disk during the run should live under the working directory so the cleanup step can delete `root.pem`, `root.cer`, and the generated PFX.

## Repository self-test

This repo runs `.github/workflows/win-ca-smoke-self-test.yml` on every push and pull request. The job calls the reusable workflow via `uses: ./.github/workflows/win-ca-smoke.yml` and uses the bundled scripts plus `scripts/Test-WinCA.ps1` to assert the pre-trust failure and post-trust success paths. If the reusable workflow regresses, the self-test will break before consumers feel the pain.
