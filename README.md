# kol-agent-sandbox

A KoLmafia-native installer for creating a **mirrored agent test/sandbox environment** backed by [loathers/kolmafia-mock](https://github.com/loathers/kolmafia-mock).

## KoLmafia install

Run in gCLI:

```text
git checkout https://github.com/donCannoli-burns/kol-agent-sandbox.git
```

Then launch the sandbox scaffold:

```text
call kol-agent-sandbox.ash install main
```

Useful commands:

```text
call kol-agent-sandbox.ash help
call kol-agent-sandbox.ash docs main
call kol-agent-sandbox.ash snapshot main
call kol-agent-sandbox.ash mock
call kol-agent-sandbox.ash status main
```

KoLmafia's Git installer syncs this repository's `scripts/` and `data/` files into the normal KoLmafia tree.

## Full host sandbox

The checkout also installs:

```text
~/.kolmafia/scripts/kol-agent-sandbox/bootstrap-agent-sandbox.sh
```

Run it from the workspace where you want the isolated mirror:

```bash
bash ~/.kolmafia/scripts/kol-agent-sandbox/bootstrap-agent-sandbox.sh \
  --branch main \
  --live ~/.kolmafia \
  --root ./kolmafia
```

The resulting layout is:

```text
./kolmafia/
├── README.html5
├── index.html5
└── sandboxes/
    └── main/
        ├── README.html5
        ├── AGENT_BOUNDARY.txt
        ├── LIVE_LOCATION.txt
        ├── SANDBOX_LOCATION.txt
        ├── sandbox-manifest.json
        ├── fixtures/
        ├── mirror/
        │   ├── scripts/
        │   ├── relay/
        │   └── ccs/
        ├── mock/
        │   └── kolmafia-mock/
        └── work/
```

The mirror is read-only. Agent edits belong in `work/`.

On refresh, the bootstrap temporarily restores owner write permission to the existing mirror, replaces it from the live code-oriented directories, and then freezes the new mirror read-only again. This makes repeated runs idempotent without requiring `sudo`.

## What is deliberately not mirrored

The host bootstrap does **not** copy:

- `settings/`
- `sessions/`
- cookies
- password hashes
- login/session material

A sandbox or mock failure is never permission to fall through to live KoLmafia.

## Existing HTML README handling

If a sandbox destination already contains `README.html5` or `README.html`, the bootstrap saves a `.pre-agent-sandbox.bak` copy and prepends a clear **SANDBOX / LIVE** location banner. It never edits the live README in place.

## kolmafia-mock

The host bootstrap clones:

```text
https://github.com/loathers/kolmafia-mock.git
```

and defaults to pinned commit:

```text
5c53bf4a5ee64d84710e7788409862bd8d2a1661
```

When Yarn/Corepack is available it runs:

```bash
yarn install --immutable
yarn vitest run
```

### Upstream mock-test compatibility

The pinned `kolmafia-mock` revision uses `data-of-loathing ^2.0.1`. That v2 client queries the former GraphQL service. Current `data-of-loathing` v3 has migrated to a local/hosted SQLite client instead.

If the upstream test suite returns `Cannot POST /graphql`, the bootstrap now records:

```text
mock_test_status: fail
mock_test_reason: upstream-data-of-loathing-v2-graphql-retired
```

and **continues creating the sandbox, manifest, logs, and HTML index**. A failed upstream dependency test is evidence about mock compatibility; it does not make the isolated mirror unusable and never authorizes fallback to live KoLmafia.

Logs are retained under:

```text
sandboxes/<branch>/logs/kolmafia-mock-install.log
sandboxes/<branch>/logs/kolmafia-mock-tests.log
```

## Update / reinstall

Update from gCLI:

```text
git update donCannoli-burns-kol-agent-sandbox
```

Clean reinstall:

```text
git delete donCannoli-burns-kol-agent-sandbox
git checkout https://github.com/donCannoli-burns/kol-agent-sandbox.git
```

## Safety boundary

This project is a test scaffold, not an alternate execution authority. Mirrors, fixtures, HTML indexes, and mocks may provide evidence about behavior; they do not authorize live game actions.
