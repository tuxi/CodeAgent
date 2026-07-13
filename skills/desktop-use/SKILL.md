---
name: desktop-use
description: Use the desktop-control MCP to inspect and operate visible desktop applications safely, including screenshot-guided UI debugging, scrolling, clicking, text entry, approval, and post-action verification.
---

# Desktop Use

Use this skill when a task requires observing or changing a real desktop app through `mcp__desktop_control__*` tools.

## Required workflow

1. Call `windows_list` and select the target by bundle ID/app name. Use the returned `$ref` for `windowRef`.
2. Call `ui_snapshot` with `options.ttlSeconds: 120` for a multi-step task.
3. Use the snapshot `$ref` with `ui_find` to resolve a small number of targets. `ui_snapshot` does not create element handles for every AX node.
4. Use only element `$ref` handles returned by `ui_find`. Never copy or infer raw `window_*`, `snapshot_*`, `el_*`, generation, timestamp, or intent values.
5. Prefer semantic actions when the target exposes the required AX action:
   - `press` when `AXPress` is present;
   - `scroll` when `AXScrollUp`/`AXScrollDown` is present;
   - `set_value` only for permitted editable roles.
6. If a semantic action returns `unsupported_action`, re-observe and use the matching bounds-based action when available:
   - `press` → `pointer_click`;
   - `scroll` → `pointer_scroll`.
   Pointer actions must still use a snapshot-scoped element `$ref`; never provide arbitrary coordinates.
7. Every mutating action follows `action_prepare` → user approval → `action_commit`.
8. After commit, capture a fresh snapshot and verify the intended UI change. Treat execution success and verification success as separate results.

## Recovery rules

- `reference_handle_required`: do not retry the raw value; obtain the required handle from the preceding tool result.
- `reference_kind_mismatch`: use the handle of the requested kind (window, snapshot, element, or intent).
- `reference_expired` or `snapshot_expired`: capture a new snapshot and repeat `ui_find`.
- `unsupported_action`: do not change action semantics or guess an element. Re-observe and select the documented pointer fallback.
- `broker_unavailable` or permission errors: report the infrastructure problem; do not use shell, AppleScript, or system screenshot fallbacks.

## Vision and evidence

Use `screenshot_capture` when AX structure is incomplete or visual state matters. The image asset is supplied to the configured multimodal model by the host runtime; do not invent a separate vision tool. After an action, preserve the before/after snapshots, diff, and evidence report when available.

Never use `run_command`, `osascript`, or arbitrary system automation as a fallback unless the user explicitly authorizes that separate capability.
