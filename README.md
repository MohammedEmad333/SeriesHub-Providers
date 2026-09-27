# SeriesHub Movies & Series Repository

Aniyomi-style repository metadata for SeriesHub movie and TV-series sources.

## Repository URL

Add this URL to SeriesHub:

`https://raw.githubusercontent.com/MohammedEmad333/SeriesHub-Providers/main/index.min.json`

Repository metadata:

`https://raw.githubusercontent.com/MohammedEmad333/SeriesHub-Providers/main/repo.json`

## Current sources

- Official YouTube / MangoTV Arabic — playback
- YOUKU Arabic — playback
- WeTV Arabic — playback
- Roya TV — metadata only
- WatanFlix — metadata only

## Repository layout

- `repo.json` — repository metadata.
- `index.json` — readable extension/source index.
- `index.min.json` — minified index consumed by SeriesHub.
- `providers/<id>/provider.json` — provider capabilities and built-in entrypoint.
- `lib/src/providers/` — reviewed provider implementations.

The index intentionally uses `artifact: "builtin"` instead of an APK filename.
SeriesHub providers are reviewed Dart implementations shipped with the app; the
remote repository controls discovery, ordering, status, and enablement only.

> Providers must only expose metadata and playback resources that are publicly
> available or otherwise authorized. Do not bypass DRM, authentication,
> paywalls, or access controls.
