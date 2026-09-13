Throwaway helpers kept because they are the fastest way to answer "what is
actually on the branch right now" before adjusting a selector. Each one sources
`../env.sh` (which reads the credential file internally) and builds the branch
DSN by swapping the host of the direct URL — nothing prints a secret.

- `peek-core.sh` — recipes, locations, households, profiles
- `peek-inventory.sh` — Test Home's inventory with days-to-expiry, grocery rows, zones
- `peek-recipes.sh` — recipes with step/ingredient counts, folders, folder items
- `peek-outcomes.sh` — food_outcomes by kind (what gates the waste scorecard)
- `use-copied-login.sh` — fallback if a future Maestro stops resolving the
  absolute `runFlow` into the repo: copies `_launch.yaml` / `_login.yaml` in.
  Not needed on Maestro 2.10, where the absolute path works.
- `package.json.bak` — `expo prebuild` rewrites the repo's package.json; build.sh
  restores it from here so no tracked file is left modified.
