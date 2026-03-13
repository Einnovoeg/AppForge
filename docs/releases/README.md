# Release Assets

Versioned release assets can be built locally with:

```bash
./scripts/package_release.sh
```

The script reads `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` from `project.yml`, generates the Xcode project, builds the Release configuration, and writes versioned artifacts plus SHA-256 checksums under `dist/`.
