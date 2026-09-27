# Adding a provider

Each provider implements `SourceProvider` and is isolated under
`lib/src/providers/<provider>/`.

## Requirements

1. Use only public or otherwise authorized metadata/playback resources.
2. Do not bypass DRM, authentication, paywalls, CAPTCHAs, or access controls.
3. Keep network parsing isolated from SeriesHub UI code.
4. Add parser tests using local HTML fixtures/strings.
5. Use stable IDs derived from canonical provider URLs.
6. Fail clearly when the upstream site changes instead of silently returning
   incorrect data.

## Provider checklist

- browse/catalog
- search
- series metadata
- episodes
- playback resolver (only when a stable authorized resource is available)
- timeout/error handling
- parser tests
