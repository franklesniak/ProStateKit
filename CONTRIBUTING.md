<!-- markdownlint-disable MD013 -->
# Contributing To ProStateKit

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-05-03
- **Scope:** Contribution expectations for ProStateKit source, docs, schemas, validation, and evidence examples.
- **Related:** [Repository Instructions](.github/copilot-instructions.md), [Execution Contract](docs/contract.md), [Evidence Schema](docs/evidence-schema.md)

Thank you for contributing. ProStateKit is a preview starter kit, so contribution quality depends on precise contracts, conservative wording, fail-closed behavior, and clear evidence.

## Expectations

- Keep pull requests small and reviewable.
- Do not include secrets in examples, tests, configs, logs, transcripts, prompts, or evidence.
- Keep sample configs safe for lab use and clearly labeled as samples.
- Runner behavior changes require Pester tests.
- Schema changes must update schema files, valid examples, invalid examples, tests, and docs together.
- Exit-code changes must update [docs/exit-codes.md](docs/exit-codes.md).
- Evidence changes must update [docs/evidence-schema.md](docs/evidence-schema.md).
- Reboot behavior changes must update [docs/reboots.md](docs/reboots.md).
- Secrets behavior changes must update [docs/secrets.md](docs/secrets.md).

## Development Setup

Install Node.js dependencies for markdown tooling:

```bash
npm install
```

Install pre-commit as a global or isolated developer tool, then install hooks:

```bash
pre-commit install
```

## Validation

Run the repository validation gates before opening a pull request:

```bash
pre-commit run --all-files
npm run lint:md
```

Run PowerShell tests with:

```powershell
Invoke-Pester -Path tests/ -Output Detailed
```

Pre-commit auto-fixes must be reviewed and included with the related change. Do not create separate formatting-only or lint-only commits.

## Code Standards

Read the relevant instruction file before changing matching files:

- Markdown: [.github/instructions/docs.instructions.md](.github/instructions/docs.instructions.md)
- PowerShell: [.github/instructions/powershell.instructions.md](.github/instructions/powershell.instructions.md)
- JSON: [.github/instructions/json.instructions.md](.github/instructions/json.instructions.md)
- YAML: [.github/instructions/yaml.instructions.md](.github/instructions/yaml.instructions.md)
- Git attributes: [.github/instructions/gitattributes.instructions.md](.github/instructions/gitattributes.instructions.md)

PowerShell code must use strict error handling, avoid secret leakage, and fail closed when proof is missing.

## Pull Requests

Before submitting:

- Confirm `pre-commit run --all-files` passes locally or equivalent CI checks passed.
- Confirm Pester tests pass when PowerShell behavior changed.
- Include docs for user-facing behavior changes.
- Include sanitized evidence examples only when they are synthetic and reviewed.
- Explain any remaining TODOs or preview limitations.

## Questions Or Issues

Check existing issues and docs first, then open a focused issue with the component, expected behavior, observed behavior, relevant redacted evidence excerpts, and validation results.

## License

By contributing, you agree that your contributions are licensed under the MIT License used by this repository.
