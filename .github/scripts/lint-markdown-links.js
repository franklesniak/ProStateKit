#!/usr/bin/env node

/**
 * Lint local Markdown links.
 *
 * External links, fragment-only links, and the PR template's required
 * GitHub-relative contributing link are intentionally ignored. The check only
 * verifies that repository-relative file links point to files or directories
 * that exist in the current checkout.
 */

const fs = require('fs');
const path = require('path');
const { globSync } = require('glob');

const REPO_ROOT = path.resolve(__dirname, '../..');
const IGNORED_DIRECTORIES = new Set([
    '.git',
    'node_modules',
    '.npm-cache',
    '.pre-commit-cache',
    '.pip-cache'
]);
const IGNORED_LINKS = new Set([
    '.github/pull_request_template.md::../blob/HEAD/CONTRIBUTING.md'
]);
const LINK_PATTERN = /\[[^\]]+\]\(([^)]+)\)/g;
const colors = {
    reset: '\x1b[0m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    cyan: '\x1b[36m',
    bold: '\x1b[1m'
};

function toRepositoryPath(filePath) {
    return path.relative(REPO_ROOT, filePath).replaceAll(path.sep, '/');
}

function resolveFilePaths(args) {
    const validFiles = [];
    const skippedFiles = [];

    for (const arg of args) {
        const absolutePath = path.isAbsolute(arg) ? arg : path.resolve(process.cwd(), arg);
        if (fs.existsSync(absolutePath) && absolutePath.endsWith('.md')) {
            validFiles.push(absolutePath);
        } else if (arg.endsWith('.md')) {
            skippedFiles.push(arg);
        }
    }

    return { validFiles, skippedFiles };
}

function findMarkdownFiles() {
    return globSync('**/*.md', {
        cwd: REPO_ROOT,
        absolute: true,
        nodir: true,
        ignore: [...IGNORED_DIRECTORIES].map((dir) => `${dir}/**`)
    });
}

function isExternalOrFragmentOnly(target) {
    if (!target || target.startsWith('#')) {
        return true;
    }

    return /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(target);
}

function normalizeTarget(rawTarget) {
    let target = rawTarget.trim();
    target = target.replace(/^<|>$/g, '');
    target = target.split('#')[0];

    if (!target) {
        return '';
    }

    try {
        return decodeURI(target);
    } catch (_error) {
        return target;
    }
}

function lintFile(filePath) {
    const repoPath = toRepositoryPath(filePath);
    const content = fs.readFileSync(filePath, 'utf8');
    const failures = [];
    let match;

    while ((match = LINK_PATTERN.exec(content)) !== null) {
        const rawTarget = match[1].trim();
        const ignoreKey = `${repoPath}::${rawTarget}`;
        if (IGNORED_LINKS.has(ignoreKey) || isExternalOrFragmentOnly(rawTarget)) {
            continue;
        }

        const target = normalizeTarget(rawTarget);
        if (!target) {
            continue;
        }

        const resolvedPath = path.resolve(path.dirname(filePath), target);
        if (!fs.existsSync(resolvedPath)) {
            const line = content.slice(0, match.index).split(/\r?\n/).length;
            failures.push({
                file: repoPath,
                line,
                target: rawTarget,
                resolved: path.relative(REPO_ROOT, resolvedPath).replaceAll(path.sep, '/')
            });
        }
    }

    return failures;
}

function main() {
    console.log(`${colors.bold}Linting local Markdown links...${colors.reset}\n`);

    const cliArgs = process.argv.slice(2);
    let files;
    if (cliArgs.length > 0) {
        const resolved = resolveFilePaths(cliArgs);
        files = resolved.validFiles;
        for (const skipped of resolved.skippedFiles) {
            console.warn(`${colors.yellow}Warning: Markdown file not found, skipping: ${skipped}${colors.reset}`);
        }
    } else {
        files = findMarkdownFiles();
    }

    const failures = files.flatMap((filePath) => lintFile(filePath));
    if (failures.length === 0) {
        console.log(`${colors.green}✓${colors.reset} All local Markdown links resolve`);
        return;
    }

    console.log(`${colors.bold}${colors.red}Broken local Markdown links:${colors.reset}\n`);
    for (const failure of failures) {
        console.log(`${colors.cyan}${failure.file}:${failure.line}${colors.reset} -> ${failure.target}`);
        console.log(`  ${colors.yellow}Resolved path missing:${colors.reset} ${failure.resolved}`);
    }

    process.exitCode = 1;
}

main();
