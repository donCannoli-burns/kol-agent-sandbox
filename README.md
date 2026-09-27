# kol-agent-sandbox

A KoLmafia-native installer for creating a **mirrored agent test/sandbox environment** using the pinned [loathers/kolmafia-mock](https://github.com/loathers/kolmafia-mock) engine with the verified SQLite compatibility provider from [donCannoli-burns/tokens-of-loathing](https://github.com/donCannoli-burns/tokens-of-loathing).

## KoLmafia install

Run in gCLI:

```text
git checkout https://github.com/donCannoli-burns/kol-agent-sandbox.git
```

Then launch the KoLmafia-side scaffold:

```text
call kol-agent-sandbox.ash install main
```

This step creates docs/fixtures only. It deliberately does **not** install a raw `kolmafia-mock` into live KoLmafia. Verified mock materialization belongs to the host bootstrap below.

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
        │   ├── kolmafia-mock/
        │   └── tokens-of-loathing/
        ├── logs/
        │   └── kolmafia-mock-compat.log
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

## Mock compatibility workflow

The sandbox keeps responsibilities separated:

```text
loathers/kolmafia-mock @ pinned upstream commit
        +
donCannoli-burns/tokens-of-loathing @ pinned verified commit
        ↓
tokens compat/kolmafia-mock/materialize.sh
        ↓
SQLite-backed compatible mock checkout
        ↓
original upstream 7-file Vitest suite
        ↓
sandbox manifest + evidence log
```

Pinned upstream mock:

```text
https://github.com/loathers/kolmafia-mock.git
5c53bf4a5ee64d84710e7788409862bd8d2a1661
```

Pinned compatibility provider:

```text
https://github.com/donCannoli-burns/tokens-of-loathing.git
5ff383e73a94aa966b8c315d680e287c5a3ed4a5
compat/kolmafia-mock/materialize.sh
```

The compatibility provider builds the current SQLite-backed client, applies only
the narrow legacy data adapter needed by the pinned mock, downloads one SQLite
snapshot, and runs the original upstream tests unchanged.

A successful bootstrap records:

```text
mock_test_status: pass
mock_test_reason: tokens-of-loathing-compat-tests-passed
mock_verified: true
```

The generated sandbox keeps both checkouts under:

```text
sandboxes/<branch>/mock/
├── kolmafia-mock/
└── tokens-of-loathing/
```

Compatibility evidence is retained in:

```text
sandboxes/<branch>/logs/kolmafia-mock-compat.log
sandboxes/<branch>/mock/kolmafia-mock/.kolmafia-mock-compat/compat-manifest.json
```

A failed compatibility check still does **not** authorize fallback to live
KoLmafia. Sandbox construction may finish so evidence can be inspected, but
`mock_verified` remains false until the compatibility tests pass.

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
