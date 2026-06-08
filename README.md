# MemoryGuard

macOS menu bar app to monitor system memory usage and alert when thresholds are exceeded.

## Local Build

```bash
./build_app.sh
open "./MemoryGuard.app"
```

## GitHub Release Distribution

This repository includes GitHub Actions workflow at `.github/workflows/release.yml`.

- Push a tag like `v1.0.0`
- Workflow builds `MemoryGuard.app`
- It uploads `MemoryGuard-v1.0.0.zip` and checksum to GitHub Releases

### Release Steps

```bash
git tag v1.0.0
git push origin v1.0.0
```

After the workflow completes, users can download the zip from the **Releases** page.

## Notes

- Current build uses ad-hoc signing in `build_app.sh`.
- For smoother end-user experience (fewer Gatekeeper warnings), use Apple Developer ID signing and notarization later.
