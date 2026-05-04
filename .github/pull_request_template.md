## Description

## Type Of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Schema or evidence contract change
- [ ] PowerShell runner or wrapper change
- [ ] Configuration/tooling change

## General Checklist

- [ ] I have read the [contributing guidelines](https://github.com/franklesniak/ProStateKit/blob/HEAD/CONTRIBUTING.md)
- [ ] My changes follow `.github/copilot-instructions.md` and applicable `.github/instructions/*`
- [ ] I have added or updated tests where appropriate
- [ ] I have updated docs for user-facing behavior changes
- [ ] I have not added secrets, tenant data, customer data, private logs, or unredacted evidence

### Pre-commit Verification

- [ ] I have run `pre-commit run --all-files` locally or verified equivalent CI/pre-commit checks passed
- [ ] I have reviewed and committed all auto-fixes made by pre-commit hooks

### PowerShell

- [ ] PSScriptAnalyzer passes locally or in CI
- [ ] Pester tests pass locally or in CI
- [ ] Runtime paths fail closed when implementation is incomplete or proof is missing

### ProStateKit Contract Checks

- [ ] Detect behavior still maps to `dsc config test`
- [ ] Remediate behavior still verifies state after set
- [ ] Raw DSC output is preserved before normalization
- [ ] Normalized evidence schema is updated if result shape changed
- [ ] Partial convergence fails closed
- [ ] Missing or unparseable proof fails closed
- [ ] No secrets are written to configs, logs, transcripts, stdout, or evidence
- [ ] Reboot behavior remains durable and re-entrant where applicable

### Documentation

- [ ] README/docs updated for user-facing behavior changes
- [ ] Exit-code docs updated if exit semantics changed
- [ ] Evidence schema docs updated if evidence changed
- [ ] Reboot/secrets docs updated if relevant

## Related Issues

Closes #
