# Security Policy

## Reporting a Vulnerability

**ProStaff API** takes security seriously. We appreciate your efforts to responsibly disclose your findings.

### Reporting Process

**DO NOT** create public GitHub issues for security vulnerabilities.

Instead, please report security vulnerabilities by emailing:

```
security@prostaff.gg
```

### What to Include

Please include the following information in your report:

- **Type of vulnerability** (e.g., SQL injection, XSS, SSRF, authentication bypass)
- **Full path** of the affected source file(s)
- **Location** of the affected code (file path, line number, commit hash)
- **Step-by-step instructions** to reproduce the issue
- **Proof-of-concept or exploit code** (if possible)
- **Impact** of the vulnerability
- **Suggested fix** (if you have one)

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Resolution Target**: Depends on severity (see below)

### Severity Levels

| Severity | Response Time | Examples |
|----------|---------------|----------|
| **Critical** | 24-48 hours | Remote code execution, SQL injection, authentication bypass |
| **High** | 3-7 days | SSRF, privilege escalation, data exposure |
| **Medium** | 7-14 days | XSS, CSRF, information disclosure |
| **Low** | 14-30 days | Rate limiting issues, verbose error messages |

## Security Measures

ProStaff API implements multiple layers of security:

### Authentication & Authorization
- ✅ JWT-based authentication with refresh tokens
- ✅ Token blacklisting on logout
- ✅ Multi-tenant data isolation via `organization_scoped`
- ✅ Role-based access control (Pundit)
- ✅ Fail-safe fallbacks (`where('1=0')` when org_id is nil)

### API Security
- ✅ Rate limiting (Rack::Attack)
  - Global: 300 req/5min
  - Login: 5 req/20sec
  - Registration: 3 req/hour
  - Password reset: 5 req/hour
- ✅ CORS configuration with explicit origin whitelist
- ✅ SSRF protection with domain whitelist + private IP blocking
- ✅ SQL injection protection (parameterized queries)
- ✅ XSS protection (Rails default escaping)

### Infrastructure Security
- ✅ HTTPS-only in production (Traefik + Let's Encrypt)
- ✅ Security headers (X-Frame-Options, X-Content-Type-Options, etc.)
- ✅ Database connection timeout (5s)
- ✅ Statement timeout (10s to prevent long-running queries)
- ✅ Prepared statements disabled (Supabase compatibility)

### Secrets Management
- ✅ No hardcoded credentials
- ✅ Environment variables for all secrets
- ✅ `.env` files properly gitignored
- ✅ Test credentials marked with `# brakeman:ignore`
- ✅ JWT_SECRET_KEY rotation supported

### Monitoring & Detection
- ✅ 401 rate spike detection (alerts when >5% of requests fail auth)
- ✅ Structured logging (Lograge JSON format)
- ✅ Audit logs for sensitive operations
- ✅ Sidekiq job monitoring with stale job detection

## Security Testing

### Automated Scans (CI/CD)

Every push triggers:

```bash
# Static Analysis (SAST)
- Brakeman         # Rails security scanner
- Bundle Audit     # Dependency vulnerabilities
- Semgrep          # Code analysis
- TruffleHog       # Secrets detection

# Dynamic Analysis (DAST)
- SSRF Protection  # 9 tests
- Authentication   # 5 tests
- SQL Injection    # 4 tests
- Secrets Scan     # 5 checks
```

### Manual Testing

Security team regularly performs:
- Manual code review
- Penetration testing
- Third-party security audits

### Current Security Status

**Last Audit**: 2026-03-04
**Overall Grade**: A (26/27 tests passed - 96%)
**Status**: Production-ready

See `.pentest/SECURITY-TEST-RESULTS.md` for detailed results.

## Compliance

ProStaff API follows industry best practices:

- ✅ **OWASP Top 10 2025** - All 10 categories covered
- ✅ **CWE Top 25** - Common weakness patterns mitigated
- ✅ **SANS Top 25** - Dangerous software errors prevented

## Security Configuration

### For Developers

**Before committing code:**

```bash
# Run security scan
./security_tests/scripts/brakeman-scan.sh

# Check for secrets
./.pentest/test-secrets-quick.sh

# Verify SSRF protection
./.pentest/test-ssrf-quick.sh
```

### For Production Deployment

**Required environment variables:**

```bash
# Strong JWT secret (min 64 characters)
JWT_SECRET_KEY=$(openssl rand -base64 64)

# Unique HashID salt (never reuse across environments)
HASHID_SALT=$(openssl rand -base64 32)

# CORS origins (explicit list, no wildcards)
CORS_ORIGINS=https://prostaff.gg,https://app.prostaff.gg
```

**Database configuration:**

```yaml
# config/database.yml (production)
production:
  connect_timeout: 5
  checkout_timeout: 5
  variables:
    statement_timeout: 10000  # 10 seconds
```

## Security Best Practices

### For Contributors

1. **Never commit secrets** - Use environment variables
2. **Always scope queries** - Use `organization_scoped(Model)`
3. **Validate user input** - Use strong parameters
4. **Parameterize SQL** - Never use string interpolation
5. **Test authentication** - Ensure endpoints require auth
6. **Use HTTPS** - Never send credentials over HTTP
7. **Rate limit** - Add throttling for expensive operations

### For Code Reviewers

Check for:

- [ ] All queries use `organization_scoped()` or explicit `organization_id` filter
- [ ] No SQL queries with string interpolation
- [ ] Controllers use `authenticate_request!`
- [ ] Strong parameters whitelist (no `permit!`)
- [ ] No secrets in code (use ENV vars)
- [ ] URLs with user input use whitelist + validation
- [ ] Brakeman reports no HIGH or CRITICAL issues

## Security Updates

### Update Policy

- **Critical vulnerabilities**: Patched within 24-48 hours
- **Dependency updates**: Monthly review cycle
- **Security advisories**: Monitored via Dependabot

### Update Notifications

Security advisories are posted to:
- GitHub Security Advisories
- Email: security@prostaff.gg

## Hall of Fame

We recognize security researchers who responsibly disclose vulnerabilities:

<!-- Contributors will be listed here after coordinated disclosure -->

*No vulnerabilities have been publicly disclosed yet.*

## Safe Harbor

ProStaff provides a safe harbor for security researchers who:

- Make a good faith effort to avoid privacy violations, data destruction, and service disruption
- Only interact with accounts you own or with explicit permission
- Do not exploit a vulnerability beyond the minimum necessary to demonstrate it
- Report vulnerabilities promptly
- Give us reasonable time to fix the issue before any public disclosure

We will not pursue legal action against researchers who follow this policy.

## Out of Scope

The following are explicitly **out of scope**:

- ❌ Social engineering attacks
- ❌ Physical attacks
- ❌ Denial of Service (DoS/DDoS)
- ❌ Spam or social engineering of ProStaff employees
- ❌ Attacks on third-party services (Riot API, PandaScore, etc.)
- ❌ Vulnerabilities in outdated browsers or plugins
- ❌ Clickjacking on pages without sensitive actions
- ❌ Missing security headers without proof of exploitability
- ❌ SSL/TLS configuration issues (handled by Traefik)

## Contact

- **Security Team**: security@prostaff.gg
- **General Support**: support@prostaff.gg
- **GitHub Issues**: For non-security bugs only

## Additional Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE Top 25](https://cwe.mitre.org/top25/)
- [Security Test Results](.pentest/SECURITY-TEST-RESULTS.md)
- [CI/CD Security Workflow](.github/workflows/README.md)

---

**Last Updated**: 2026-03-04
**Policy Version**: 1.0
