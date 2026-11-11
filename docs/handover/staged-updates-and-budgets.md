# Staged updates and request/privacy budgets (H5)

## `bloom update`

1. **Preconditions.** Local changes refuse the update. Only a fast-forward of
   the recorded branch is accepted.
2. **Validate the candidate.** The target commit is exported with `git archive`
   into a private temporary directory and checked statically:
   - required files are present and `VERSION` is non-empty
   - every Python tool and helper compiles
   - Hyprland Lua files pass `luac -p` when available
   A failing candidate is refused, and the checkout and service stay untouched.
3. **Switch and verify.** The checkout fast-forwards (`git merge --ff-only`),
   then `install --restart` runs and waits for the shell to answer.
4. **Roll back on failure.**
   - The checkout returns to the previous revision, the branch is reset, and
     the previous version is reinstalled and verified again.
   - The error says truthfully whether the previous version is running and
     answering again, or was restored but isn't answering (then run
     `bloom doctor`).
   - `update.json` records `lastGood` only after the health check passes.
5. **Explicit rollback.** `bloom update --rollback` returns to the previous
   revision through the same validate, switch and verify steps.

**Scope of a rollback.** It covers Bloom's code and the files the installer
manages. Settings and UI state are not versioned or downgraded, packages are
never downgraded, and `bloom-shell-deps` is left as it is.

**Ruling.** Immutable per-commit deployment directories (a `current` link and
a last-good link) are not implemented. Installed links point into the checkout,
and changing that needs an install-layout migration for existing installs.
- What is done: validating before the switch plus a health-verified rollback.
  These meet the exit condition that a broken candidate can't silently replace
  the last-good desktop, and that the rollback scope is stated truthfully.
- Cost: during the seconds between the fast-forward and the restart,
  Quickshell may live-reload files from the new revision.

## Requests and privacy

- **Network helper.** `Http.get` refuses plain HTTP to remote hosts; loopback is
  allowed for tests. Replies over 256 KiB are discarded (a caller may set a
  lower limit). A keyed request cancels the previous one with the same key, so
  a stale answer can't overwrite a newer one. Every request has a timeout.
- **Weather.** One HTTPS IP lookup (ipapi.co). There is no plaintext fallback
  (ip-api.com) and no invented default location (Delhi). Without a location
  there is no reading, and `Weather.needsLocation` asks the owner to set one in
  Settings. This deliberately departs from Windows Bloom's Delhi default, for
  privacy. Forecast replies are capped at 64 KiB.
- **City search.** The Settings city search uses the same helper, with a timeout,
  a 64 KiB cap and cancellation of older searches.
- **Assistant.**
  - Only the newest history within 48 KiB is sent, starting on a user turn, and
    the newest message is always included.
  - Answers stop at 64 Ki characters (`too-long`) or after 180 s (`timeout`).
  - Any single stream line is capped at 1 MiB.
  - The key stays in the keyring and is passed on stdio. Prompts and answers
    are never logged.
- **Clipboard previews.** An image over 32 MiB isn't decoded into the RAM-backed
  runtime directory, and only the newest 60 previews are kept. That number is
  higher when more are requested at once, and served images count as newest.
- **Notification history and state** are bounded by the state document budgets
  (see [state documents](state-documents.md)).

## Licenses and provenance

`licenses/fonts.txt` carries the copyright notices taken from each bundled
font's name table (Inter, Selawik, Syne) and the SIL OFL 1.1 text.
`tests/scripts/test_fonts.sh` fails if any bundled font lacks a notice. Lucide
icons are covered by `licenses/lucide.txt`. The theme limitations are in
[theme ownership](theme-ownership.md).

## Tests

- `test_http.sh`: timeout, size budget, plaintext refusal and keyed
  cancellation against local servers.
- `tst_weather.qml`: no plaintext fallback, no default location.
- `test_assistant.sh`: flood stopped at the cap, slow stream stopped at the
  deadline.
- `tst_assistant.qml`: bounded history.
- `test_clip_thumbs.sh`: oversized images and cache bound.
- `lifecycle_cases.py`: a broken candidate is refused before any change; an
  unhealthy candidate rolls back to a verified last-good; the earlier update
  and rollback cases.
- `test_fonts.sh`: every bundled font has a notice.
