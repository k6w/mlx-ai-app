# Releasing

Releases build from `v*` tags through `.github/workflows/release.yml`. They are intentionally ad-hoc signed: no Developer ID certificate, Apple ID, team identifier, notarization credential, or personal email is used.

Update the changelog, commit, and push a semantic-version tag:

```sh
git tag v1.0.0
git push origin main v1.0.0
```

The workflow bundles the `uv` runtime bootstrap, runs the full test suite, creates the DMG, verifies that the app signature is ad hoc, and publishes a GitHub Release. No repository secrets are required.

Because the release is not notarized, macOS Gatekeeper may ask users to right-click the app and choose **Open**, or approve it from **System Settings → Privacy & Security**.
