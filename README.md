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
