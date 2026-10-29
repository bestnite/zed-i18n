# This fork: Windows x86_64 only

Upstream: [LI-NA/zed-i18n](https://github.com/LI-NA/zed-i18n) (localization toolkit for the
Zed editor). This fork exists to publish a **Windows x86_64** build only, and to keep the
Zed version pinned under local control.

Everything else (translation catalog, extraction, patch logic) comes straight from upstream
and is tracked, not rewritten.

## Divergences from upstream

Keep this list short and mergeable — it is the complete set of local changes:

| Path | Change | Why |
| --- | --- | --- |
| `.github/workflows/windows-only.yml` | added | Thin dispatcher that runs `i18n-release.yml` with `platforms=windows-x86_64`. |
| `.github/workflows/i18n-release.yml` | `push: tags` trigger removed; final "Update packaging" step removed | Tags must not launch a full multi-platform build; packaging updates a Homebrew tap and a Scoop bucket that only exist under `LI-NA`. |
| `.github/workflows/i18n-update-packaging.yml` | deleted | No Homebrew tap / Scoop bucket in this fork. |
| `.github/workflows/i18n-linux-builder.yml` | deleted | The GHCR Linux builder image is only used by Linux builds. |
| `config/distribution.toml` | `[publisher].url` points here | About dialog links to this fork. The update manifest URL needs no change: it is derived from `github.repository` at build time, so it already resolves to this fork's releases. |
| `tests/test_packaging.py`, `tests/test_linux_builder_workflow.py` | packaging-workflow assertions removed | Assertions targeted the deleted workflows. |

`config/project.toml` is never edited by hand — it is updated by the upstream sync commits.

## Building

`windows-only.yml` is dispatch-only. Artifacts (`.exe` installer + portable `.zip`) land on the
`Release <ref>` run it dispatches, on a `windows-2022` runner, ~65 minutes.

```bash
# artifacts only (retained 3 days)
gh workflow run windows-only.yml --repo bestnite/zed-i18n --ref master

# publish a release: the tag must already exist in this repository
gh workflow run windows-only.yml --repo bestnite/zed-i18n --ref master \
  -f upload_to_release=true -f release_tag=v1.25.3-i18n.1
```

Publishing uploads the assets to a draft release, validates them, then un-drafts. Auto-update in
the shipped build reads `releases/latest/download/manifest.json` from this repository, so only
Windows assets need to exist for updates to work on Windows.

No repository secrets are required. Code signing uses Azure Trusted Signing variables when
present; without them the build prints `Windows signing variables are incomplete; building
unsigned installer.` and produces an unsigned installer (Windows SmartScreen will warn).

## Syncing upstream

```bash
cd ~/dev/zed-i18n
git fetch upstream --tags
git merge upstream/master          # conflicts, if any, only in the files listed above
git push origin master
```

Then check what upstream pinned and rebuild:

```bash
cat config/project.toml            # zed_version / zed_commit must match the release you want
gh workflow run windows-only.yml --repo bestnite/zed-i18n --ref master
```

Notes:

- Upstream's version bumps are single commits that touch `config/project.toml` plus translation
  files, so merges are usually trivial. When a conflict does happen, upstream wins on everything
  except the six paths in the table above.
- The `validate` job runs `tests.test_zed_patch_contracts` and `tests.test_universal_apply_contracts`
  against the freshly fetched Zed source with `ZED_I18N_REQUIRE_ZED_PATCH_CONTRACT=1`. That is the
  early-warning system for upstream Zed renaming files or changing `script/bundle-windows.ps1`:
  it fails in ~5 minutes instead of 65. Do not remove it.
- Only push the release tag you intend to publish (`git push origin refs/tags/<tag>`); tags are not
  copied by the fork, and `i18n-release.yml` no longer runs on tag pushes.

## Known limits

- Windows x86_64 (amd64) only. No macOS, Linux, or Windows arm64 assets.
- Binaries are unsigned.
- `i18n-publish-existing.yml` is kept as a recovery path for re-publishing assets from a finished
  build run.
