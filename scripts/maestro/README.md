Ad-hoc Maestro flows used against the acceptance branch (2026-09-05). Run from a directory that also
holds copies of `.maestro/acceptance/_login.yaml` and `_launch.yaml` (they `runFlow: _login.yaml`):
  maestro --device <udid> test -e TEST_EMAIL=... -e TEST_PASSWORD=... c-residue.yaml
- c-residue.yaml — removes 12-expiring-swipe's residue through the app UI (never SQL): the `needed`
  Milk grocery row and the `out` Milk row (deleting it records one `used` ending).
- p-two-endings.yaml — diagnostic: two Out→Delete endings in one app session WITHOUT launchApp
  (launch the app yourself, e.g. with SIMCTL_CHILD_CFNETWORK_DIAGNOSTICS=3 xcrun simctl launch ...).
