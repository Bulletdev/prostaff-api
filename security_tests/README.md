# ProStaff API - Security Testing Lab

Comprehensive security testing suite for continuous security validation.

##  Overview

This lab provides automated security testing tools to ensure the API remains secure throughout development and in production.

**Key Features:**
- OWASP Top 10 coverage
- Automated vulnerability scanning
- Static code analysis
- Dependency vulnerability checks
- Penetration testing tools

##  Quick Start

### 1. Setup the Security Lab

```bash
./security_tests/zap-setup.sh
```

This installs:
- OWASP ZAP (web application scanner)
- Brakeman (Rails security analysis)
- Semgrep (static analysis)
- Trivy (container scanning)
- OWASP Dependency Check

### 2. Run Quick Security Scan

```bash
# Make sure API is running first
bundle exec rails server

# In another terminal
./security_tests/scripts/full-security-audit.sh
```

### 3. Review Results

Reports are generated in `security_tests/reports/audit-TIMESTAMP/`

##  Security Tools

### 1. OWASP ZAP (Web Application Scanner)

**Purpose**: Finds vulnerabilities in running web applications

#### Baseline Scan (Passive)
```bash
./security_tests/scripts/zap-baseline-scan.sh http://localhost:3333
```

**Use**: Safe for production, no aggressive testing

#### API Scan
```bash
./security_tests/scripts/zap-api-scan.sh \
  http://localhost:3333 \
  http://localhost:3333/api-docs/v1/swagger.json
```

**Use**: Tests API endpoints using OpenAPI spec

#### Full Scan (Active) ⚠️
```bash
./security_tests/scripts/zap-full-scan.sh http://localhost:3333
```

**Use**: Aggressive testing - **ONLY on local/staging**, never production!

**What it finds:**
- SQL injection
- XSS (Cross-Site Scripting)
- CSRF vulnerabilities
- Authentication issues
- Session management flaws
- Security header misconfigurations

### 2. Brakeman (Rails Security Scanner)

**Purpose**: Static analysis of Rails code for security issues

```bash
./security_tests/scripts/brakeman-scan.sh
```

**What it finds:**
- SQL injection risks
- Command injection
- Mass assignment vulnerabilities
- Cross-site scripting
- Unsafe redirects
- Session security issues

**Output**: HTML + JSON reports in `security_tests/reports/brakeman/`

### 3. Dependency Vulnerability Scanner

**Purpose**: Checks gems for known vulnerabilities

```bash
./security_tests/scripts/dependency-scan.sh
```

**Tools used:**
- Bundle Audit (Ruby gems)
- OWASP Dependency Check (comprehensive)

**What it finds:**
- Outdated gems with CVEs
- Known security vulnerabilities
- Recommended updates

### 4. Semgrep (Static Analysis)

**Purpose**: Pattern-based code analysis

```bash
docker-compose -f security_tests/docker-compose.security.yml run semgrep
```

**What it finds:**
- Hardcoded secrets
- Insecure crypto usage
- SSRF vulnerabilities
- Common security anti-patterns

### 5. Trivy (Container Scanner)

**Purpose**: Scans Docker images for vulnerabilities

```bash
docker-compose -f security_tests/docker-compose.security.yml run trivy \
  image prostaff-api:latest
```

**What it finds:**
- OS package vulnerabilities
- Application dependency issues
- Misconfigurations

### 6. Nuclei (Vulnerability Scanner)

**Purpose**: Fast template-based vulnerability detection

```bash
docker-compose -f security_tests/docker-compose.security.yml run nuclei \
  -u http://localhost:3333 \
  -t /templates/
```

## 📊 Understanding Reports

### Severity Levels

- **Critical**: Immediate fix required (RCE, SQL injection)
- **High**: Fix ASAP (authentication bypass, XSS)
- **Medium**: Fix before production (information disclosure)
- **Low**: Fix when possible (missing headers)
- **Info**: Best practices (recommendations)

### ZAP Reports

HTML reports show:
- **Risk**: Critical/High/Medium/Low
- **Confidence**: High/Medium/Low (false positive likelihood)
- **Affected URLs**: Where vulnerability exists
- **Solution**: How to fix

**Triage Priority**: High Risk + High Confidence first

### Brakeman Reports

```
Confidence Levels:
- High: Very likely a real issue
- Medium: Probably an issue
- Low: Might be false positive
```

**Fix High confidence issues first**, review medium/low.

### Dependency Scan

Shows:
- **CVE ID**: Common Vulnerabilities and Exposures number
- **CVSS Score**: 0-10 severity (7+ is HIGH, 9+ is CRITICAL)
- **Affected Version**: Your version
- **Fixed In**: Version to upgrade to

##  OWASP Top 10 Testing

Comprehensive checklist: [`OWASP_TOP_10_CHECKLIST.md`](./OWASP_TOP_10_CHECKLIST.md)

Quick reference:

| Risk | Tool | Test Command |
|------|------|--------------|
| A01 - Broken Access Control | ZAP, Manual | Try accessing other org's data |
| A02 - Cryptographic Failures | Brakeman, Semgrep | Check for weak crypto |
| A03 - Injection | ZAP, Brakeman | SQL/Command injection tests |
| A04 - Insecure Design | Manual, Code Review | Review architecture |
| A05 - Security Misconfiguration | ZAP, Brakeman | Check headers, configs |
| A06 - Vulnerable Components | Bundle Audit, OWASP DC | Scan dependencies |
| A07 - Auth Failures | ZAP, Manual | Test weak passwords, sessions |
| A08 - Integrity Failures | Semgrep | Check deserialization |
| A09 - Logging Failures | Manual, Code Review | Review logging |
| A10 - SSRF | Manual, Nuclei | Test external requests |

## 🔄 CI/CD Integration

### GitHub Actions

See `.github/workflows/security-scan.yml`

```yaml
name: Security Scan
on: [push, pull_request]
jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Brakeman Scan
        run: ./security_tests/scripts/brakeman-scan.sh
      - name: Dependency Check
        run: ./security_tests/scripts/dependency-scan.sh
```

### Pre-commit Hook

```bash
# .git/hooks/pre-commit
#!/bin/bash
./security_tests/scripts/brakeman-scan.sh
if [ $? -ne 0 ]; then
  echo "Security issues found! Fix before committing."
  exit 1
fi
```

##  Manual Security Testing

### 1. Authentication Testing

```bash
# Test weak password
curl -X POST http://localhost:3333/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"123","organization_name":"Test"}'

# Test invalid token
curl -H "Authorization: Bearer INVALID" \
     http://localhost:3333/api/v1/dashboard

# Test expired token (wait 15+ min or forge old token)
curl -H "Authorization: Bearer EXPIRED_TOKEN" \
     http://localhost:3333/api/v1/dashboard
```

### 2. Authorization Testing

```bash
# Get token for Org A
TOKEN_A=$(curl -X POST http://localhost:3333/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"orga@test.com","password":"password"}' \
  | jq -r '.token')

# Try to access Org B's player
curl -H "Authorization: Bearer $TOKEN_A" \
     http://localhost:3333/api/v1/players/ORG_B_PLAYER_ID
# Should return 404 or 403
```

### 3. Input Validation Testing

```bash
# SQL Injection attempt
curl "http://localhost:3333/api/v1/players?name=admin'%20OR%20'1'='1"

# XSS attempt
curl -X POST http://localhost:3333/api/v1/players \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"<script>alert(1)</script>"}'

# Command injection attempt
curl -X POST http://localhost:3333/api/v1/players \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"summoner_name":"; cat /etc/passwd"}'
```

### 4. Rate Limiting Testing

```bash
# Brute force login
for i in {1..100}; do
  curl -X POST http://localhost:3333/api/v1/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"test@test.com","password":"wrong"}' &
done

# Should eventually return 429 Too Many Requests
```

### 5. SSRF Testing

```bash
# Try to access internal services
curl -X POST http://localhost:3333/api/v1/players/import \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"api_url":"http://localhost:6379"}'

# Should be blocked
```

## 📈 Continuous Security

### Daily
```bash
# Quick health check
./security_tests/scripts/brakeman-scan.sh
```

### Weekly
```bash
# Dependency check
./security_tests/scripts/dependency-scan.sh
bundle update --patch  # Security patches only
```

### Before Each Release
```bash
# Full audit
./security_tests/scripts/full-security-audit.sh http://staging-url

# Review all reports
ls -la security_tests/reports/audit-*/
```

### Monthly
```bash
# Comprehensive testing
./security_tests/scripts/full-security-audit.sh
./security_tests/scripts/zap-full-scan.sh http://staging-url

# Third-party penetration test (recommended)
# Contact security firm
```

## 🎓 Best Practices

### Before Development
1. Review OWASP Top 10 checklist
2. Enable Brakeman in IDE
3. Set up pre-commit hooks

### During Development
1. Run Brakeman on file save
2. Manual security testing for new endpoints
3. Security-focused code reviews

### Before Deployment
1. Full security audit
2. Fix all critical/high issues
3. Document accepted risks
4. Update security documentation

### In Production
1. Monitor security logs
2. Alert on suspicious activity
3. Regular penetration testing
4. Incident response plan ready

## 🚨 Incident Response

If vulnerability found in production:

1. **Assess**: Severity and impact
2. **Contain**: Disable affected feature if critical
3. **Fix**: Develop and test patch
4. **Deploy**: Emergency deployment
5. **Communicate**: Notify affected users
6. **Learn**: Post-mortem and prevent recurrence

## 📚 Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)
- [ZAP User Guide](https://www.zaproxy.org/docs/)
- [Brakeman Documentation](https://brakemanscanner.org/docs/)

## 🔐 Security Contacts

- **Security Issues**: security@prostaff.gg
- **Bug Bounty**: N/A (consider setting up)

---

**Remember**: Security is not a one-time task, it's a continuous process!
