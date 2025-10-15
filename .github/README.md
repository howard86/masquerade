# GitHub Actions Local Testing

This directory contains tools and scripts for testing GitHub Actions workflows locally before pushing to GitHub.

## Quick Start

### Option 1: Using act (Recommended)

```bash
# Test all CI jobs (dry run)
act -W .github/workflows/ci.yml --dryrun

# Test specific jobs
act -W .github/workflows/ci.yml -j pre-commit --dryrun
act -W .github/workflows/ci.yml -j analyze-and-test --dryrun
act -W .github/workflows/ci.yml -j security --dryrun
```

### Option 2: Using Manual Script

```bash
# Run the manual test script
./scripts/test-workflows.sh
```

### Option 3: Using Docker

```bash
# Run Docker-based tests
./scripts/test-workflows-docker.sh
```

## Available Tools

### 1. act - GitHub Actions Local Runner

- **File**: `~/.config/act/actrc` (configuration)
- **Usage**: `act -W .github/workflows/ci.yml -j JOB_NAME --dryrun`
- **Best for**: Testing complete workflow structure

### 2. Manual Testing Script

- **File**: `scripts/test-workflows.sh`
- **Usage**: `./scripts/test-workflows.sh`
- **Best for**: Quick local validation

### 3. Docker Testing

- **Files**: `Dockerfile.testing`, `scripts/test-workflows-docker.sh`
- **Usage**: `./scripts/test-workflows-docker.sh`
- **Best for**: Testing in isolated environment

## Workflow Status

| Workflow                                 | Status     | Notes                                         |
| ---------------------------------------- | ---------- | --------------------------------------------- |
| CI (`ci.yml`)                            | ✅ Working | Essential jobs: pre-commit, analyze, security |
| Dependabot (`dependabot-auto-merge.yml`) | ✅ Working | Testable with act                             |

### CI Workflow Jobs

1. **pre-commit** - Pre-commit hooks validation
2. **analyze-and-test** - Code analysis and unit tests
3. **security** - Security vulnerability scanning

## Fixed Issues

1. **Pre-commit job missing Flutter setup** - Added Java and Flutter setup steps
2. **Missing dependencies** - All required tools now properly configured
3. **Workflow simplification** - Removed platform builds, kept essential jobs only
4. **Faster CI execution** - Streamlined workflow focuses on code quality and security

## Troubleshooting

### Common Issues

1. **act validation errors**: Some workflows may have validation issues with act but work fine on GitHub
2. **Docker permission errors**: Ensure Docker daemon is running and you have proper permissions
3. **Flutter not found**: Make sure Flutter is installed and in PATH

### Debug Commands

```bash
# Check act version
act --version

# List available workflows
act --list

# Check Docker
docker --version
docker ps

# Check Flutter
flutter --version
dart --version
```

## Best Practices

1. **Always test locally** before pushing to GitHub
2. **Use dry-run first** to validate workflow structure
3. **Test individual jobs** before running entire workflows
4. **Keep tools updated** for better compatibility
5. **Document any issues** you encounter

## Documentation

- [Complete Testing Guide](../docs/github-actions-local-testing.md)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [act Documentation](https://github.com/nektos/act)
