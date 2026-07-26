# ktracer_center

Repository for `ktracer_center` (app).

## Commands

- `flutter pub get`\n- `flutter analyze`\n- `flutter test`

## Sibling dependencies

This repo uses git dependencies on other private repos under `PowerRanger2130`:

- `strworks` - https://github.com/PowerRanger2130/strworks.git

For local path overrides when multiple repos are cloned side-by-side, see the `flutter-ecosystem` repo or run `generate_overrides.ps1`.

## Cursor Cloud specific instructions

- Run `flutter pub get` after clone.
- For tasks spanning multiple packages, use a **multi-repo Cloud Agent environment** â€” see `ecosystem/repos.yaml` bundles in the monorepo orchestration repo.
- Never commit `.env` files; use Cursor Cloud Secrets for API keys and database credentials.

### Related bundles

_See ecosystem/repos.yaml._
