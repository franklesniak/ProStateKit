# Post-Public-Flip TODO

This file tracks work that cannot be completed while the repository is private.
Delete this file as the final step after every item is complete.

- [ ] Change repository visibility from Private to Public.
- [ ] Enable Private Vulnerability Reporting (Settings -> Security -> Private vulnerability reporting).
- [ ] Replace private-staging security reporting text in `SECURITY.md` with PVR instructions and the advisory submission URL.
- [ ] Update `.github/ISSUE_TEMPLATE/config.yml` security URL to `https://github.com/franklesniak/ProStateKit/security/advisories/new`.
- [ ] Replace private-staging Code of Conduct reporting text in `CODE_OF_CONDUCT.md` with the final public contact method.
- [ ] Confirm the Discussions link in `.github/ISSUE_TEMPLATE/config.yml` resolves.
- [ ] Configure branch protection on `main` once workflow names and required checks have stabilized:
  - Require pull requests before merging.
  - Require status checks to pass: placeholder check, markdown lint, PowerShell CI, data/schema validation, pre-commit.
  - Require branches to be up to date before merging (optional, recommended).
  - Require CODEOWNERS review.
- [ ] Pin the DSC version in `README.md`, `docs/contract.md`, sample manifests, and any deck references.
- [ ] Run a dry release through `Tools/New-Package.ps1` after packaging is implemented and confirm `bundle.manifest.json` and SHA-256 checksum file are produced.
- [ ] Add or enable the tag-triggered release workflow once `Tools/New-Package.ps1` produces real artifacts.
- [ ] Remove this `_TODO.md` file.
