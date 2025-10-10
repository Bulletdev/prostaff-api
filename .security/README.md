# Security Configuration

This directory contains security scanner configurations and ignore files.

## Configuration Files

### `.brakeman.ignore`
Ignores specific Brakeman warnings that are false positives:
- **Mass Assignment on `:role`**: The `:role` field is a player position (Top, Jungle, etc.), not a Rails authorization role
- **Rails EOL warning**: Rails 7.1.x is still secure, upgrade planned for future sprint

### `.semgrepignore`
Excludes files from Semgrep static analysis:
- Test scripts with test-only credentials
- Load testing and security testing directories
- Generated files and documentation

## Test Credentials Security

Test credentials are handled securely:

1. **Environment Variables First**: All scripts check `ENV['TEST_EMAIL']` and `ENV['TEST_PASSWORD']` first
2. **Fallback for Development**: Fallback to test credentials only in local development
3. **CI/CD Uses Secrets**: GitHub Actions uses repository secrets
4. **Clearly Marked**: All test credentials have comments indicating they're test-only
5. **Brakeman Annotations**: `brakeman:ignore:HardcodedSecret` on test credential fallbacks

## CI/CD Security Scans

GitHub Actions runs these security tools:

| Tool | Purpose | Frequency |
|------|---------|-----------|
| **Brakeman** | Rails code security | Every push/PR |
| **Bundle Audit** | Gem vulnerabilities | Every push/PR |
| **Semgrep** | Static analysis | Every push/PR |
| **TruffleHog** | Secret detection | Every push/PR |
| **OWASP ZAP** | Runtime security | Nightly |

## Adding Ignored Warnings

### Brakeman
Add to `.brakeman.ignore` with fingerprint from report:
```json
{
  "warning_type": "Type",
  "fingerprint": "abc123...",
  "note": "Explanation why this is safe"
}
```

### Semgrep
Add to `.semgrepignore`:
```
# Comment explaining why
path/to/file.rb
```

## Running Scans Locally

```bash
# Brakeman
gem install brakeman
brakeman --rails7 --format html --output brakeman-report.html

# Bundle Audit
gem install bundler-audit
bundle-audit update
bundle-audit check

# Semgrep (requires Docker)
docker run --rm -v $(pwd):/src returntocorp/semgrep semgrep scan --config=auto
```

## Security Policy

1. ✅ **Never commit real secrets** - Use environment variables
2. ✅ **Test credentials are clearly marked** - Comments and annotations
3. ✅ **Production uses secrets management** - GitHub Secrets, AWS Secrets Manager, etc.
4. ✅ **Regular dependency updates** - Weekly bundle updates
5. ✅ **Security scans before merge** - CI/CD enforces checks

## Questions?

See [TESTING_GUIDE.md](../DOCS/tests/TESTING_GUIDE.md) for complete security testing documentation.
