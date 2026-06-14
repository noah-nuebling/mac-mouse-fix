---
name: logitech-solaar-reference
description: Solaar reference containing raw reverse-engineered protocol information for Logitech HID++ 2.0. Use this to lookup feature payloads, settings formats, control IDs, and device quirks.
---

# Logitech HID++ Solaar Reference Guide

This skill provides direct access to the reverse-engineered Logitech HID++ 2.0 implementation from Solaar, the primary open-source Linux device manager for Logitech devices.

Use these files to look up feature IDs, packet byte structures, command indices, and custom payload layouts.

---

## 1. File Reference Directory

The raw Solaar source files are stored in this skill's `references/` directory:

| Filename | Purpose | Key Details |
|---|---|---|
| [`settings_templates.py`](file:///Users/shawnrain/Library/Mobile%20Documents/com~apple~CloudDocs/Shawn%20Rain/Vibe-Coding/MacMouseFix/.agents/skills/logitech-solaar-reference/references/settings_templates.py) | **Core Feature Implementation** | Contains the exact byte configurations for reading/writing DPI (`0x2201`/`0x2202`), SmartShift (`0x2110`/`0x2111`), HiRes Scroll (`0x2121`), etc. |
| [`hidpp20_constants.py`](file:///Users/shawnrain/Library/Mobile%20Documents/com~apple~CloudDocs/Shawn%20Rain/Vibe-Coding/MacMouseFix/.agents/skills/logitech-solaar-reference/references/hidpp20_constants.py) | **Feature IDs & Names** | Full database mapping 16-bit Feature IDs to their human-readable feature names. |
| [`hidpp20.py`](file:///Users/shawnrain/Library/Mobile%20Documents/com~apple~CloudDocs/Shawn%20Rain/Vibe-Coding/MacMouseFix/.agents/skills/logitech-solaar-reference/references/hidpp20.py) | **Low-level protocol layer** | Probing methods, features index lookup, connection state changes, and packet formatting. |
| [`special_keys.py`](file:///Users/shawnrain/Library/Mobile%20Documents/com~apple~CloudDocs/Shawn%20Rain/Vibe-Coding/MacMouseFix/.agents/skills/logitech-solaar-reference/references/special_keys.py) | **Control ID (CID) mappings** | Key map database containing Logitech Control IDs (CIDs) and standard Task/Trigger IDs (TIDs) for side buttons and gestures. |

---

## 2. Common Reference Lookup Recipes

### A. How to decode a Feature payload format
Search inside [`settings_templates.py`](file:///Users/shawnrain/Library/Mobile%20Documents/com~apple~CloudDocs/Shawn%20Rain/Vibe-Coding/MacMouseFix/.agents/skills/logitech-solaar-reference/references/settings_templates.py) for the feature name (e.g. `AdjustableDpi` or `SmartShift`).
You will see Python structure definitions with byte counts and offsets. For example, search for `class DPI_SENSITIVITY` or similar, which details how DPI steps and boundaries are read or written.

### B. Finding a Control ID (CID)
If a mouse sends a button report with CID `0x00D7` or `0x0056`, look inside [`special_keys.py`](file:///Users/shawnrain/Library/Mobile%20Documents/com~apple~CloudDocs/Shawn%20Rain/Vibe-Coding/MacMouseFix/.agents/skills/logitech-solaar-reference/references/special_keys.py) to find its name and layout.
Example:
- `0x0053` corresponds to `Back` / `CID_BACK`.
- `0x0056` corresponds to `Forward` / `CID_FORWARD`.
- `0x00C4` corresponds to `SmartShift toggle button`.
- `0x00D7` corresponds to `Gesture Button` / `Mode-Shift`.

### C. Reading HID++ Error Packets
If your `sendAndWaitWithTimeout` receives `resp[2] == 0xFF`, search [`hidpp20.py`](file:///Users/shawnrain/Library/Mobile%20Documents/com~apple~CloudDocs/Shawn%20Rain/Vibe-Coding/MacMouseFix/.agents/skills/logitech-solaar-reference/references/hidpp20.py) for error code mappings (e.g., `0x01` = `ERR_INVALID_SUBID`, `0x04` = `ERR_BUSY`, `0x07` = `ERR_INVALID_FUNCTION_ID`).
