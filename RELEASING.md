# Releasing

Releases build from `v*` tags through `.github/workflows/release.yml`.

Configure these GitHub Actions secrets:

- `DEVELOPER_ID_CERTIFICATE_P12`: base64 Developer ID Application certificate.
- `DEVELOPER_ID_CERTIFICATE_PASSWORD`: certificate export password.
- `MACOS_SIGN_IDENTITY`: full Developer ID Application identity.
- `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_PASSWORD`: notarization credentials.

Update the changelog, commit, and push a semantic-version tag:

```sh
git tag v1.0.0
git push origin main v1.0.0
```

The workflow bundles `uv`, tests, signs with hardened runtime, creates and signs a DMG, notarizes and staples it, verifies Gatekeeper acceptance, and publishes a GitHub Release.
