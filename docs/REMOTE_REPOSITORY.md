# Remote provider repository

SeriesHub reads `index.min.json` from this repository to decide which built-in
providers are visible, their order, health status, and capabilities.

## Safety model

The remote repository never ships executable Dart code to the app. Provider
implementations remain built into a reviewed SeriesHub/SeriesHub-Providers
release. The remote index can only configure providers the installed app already
knows about.

Unknown provider IDs are ignored by the app.

## Status values

- `working`: catalog and playback are available.
- `metadata_only`: browse/details/episodes are available, playback is not.
- `broken`: temporarily unavailable.
- `disabled`: intentionally disabled.

## Disabling a provider without an app release

Set both `enabled: false` and `status: "disabled"` in `index.json`, regenerate
`index.min.json`, and merge to `main`.

Default index URL:

`https://raw.githubusercontent.com/MohammedEmad333/SeriesHub-Providers/main/index.min.json`
