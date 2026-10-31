# Bloom Linux port

The Windows Bloom checkout at `../bloom` is the UI and UX reference for this
Linux port. For every notch, dock, OSD, notification, and settings surface:

1. Read the matching React component and CSS in `../bloom/src` before editing
   QML. Port its dimensions, spacing, type, colours, states, navigation,
   interaction. For animation changes, follow the owner's current motion
   policy in `docs/ui-parity.md#motion`.
2. Use Linux services for the underlying action. Keep the same visible
   interaction where the platform supports it; report real capability gaps
   instead of inventing a different interface or presenting fake controls.
3. Compare an isolated-compositor screenshot and exercise the interaction
   before updating the live shell. Keep the owner's settings and unrelated
   services intact.

Run `CI=true tests/run-all.sh` from this repo for the complete local gate.
Generated Lucide icons come from `node tools/gen-icons.mjs`. Static device art
is exported from the Windows source by `node tools/gen-device-art.mjs`.
