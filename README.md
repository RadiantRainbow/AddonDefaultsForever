Some defaults for addons in Forever

## Usage

Edit `AddonDefaultsForever.lua` and add entries to `ns.config`.

Each entry supports:

- `addon` — addon folder name (case-insensitive)
- `db` — global saved variable name
- `path` — optional dot-separated sub-key (e.g. `"profile"`)
- `defaults` — table of key/value pairs to enforce
- `mode` — `"force"` to overwrite, `"default"` to only set if nil
- `poll` — `true` to re-apply every 5 seconds while loaded

## Addons

- Buffet: disable hearthstone default.
- RXP: silence ads.
