# OWASP Top 10 Security Checklist - ProStaff API

Comprehensive security checklist based on OWASP Top 10 2021

## A01:2021 – Broken Access Control

### Authentication & Authorization

- [ ] **JWT Token Security**
  - [ ] Tokens have expiration time
  - [ ] Refresh tokens implemented securely
  - [ ] Token blacklist on logout
  - [ ] Token stored securely (not in localStorage for frontend)
  - [ ] Secret key is strong and environment-specific

- [ ] **API Authorization**
  - [ ] All endpoints require authentication (except public routes)
  - [ ] Pundit policies implemented for all resources
  - [ ] Organization-scoped queries (`current_organization` check)
  - [ ] Role-based access control (admin, coach, analyst, viewer)
  - [ ] No IDOR (Insecure Direct Object Reference) vulnerabilities

- [ ] **Tests**
  ```bash
  # Manual test
  curl -H "Authorization: Bearer INVALID_TOKEN" http://localhost:3333/api/v1/dashboard
  # Should return 401 Unauthorized

  # Try accessing another org's data
  curl -H "Authorization: Bearer USER_ORG_A_TOKEN" \
       http://localhost:3333/api/v1/players/ORG_B_PLAYER_ID
  # Should return 403 Forbidden or 404 Not Found
  ```

## A02:2021 – Cryptographic Failures

### Data Encryption

- [ ] **Passwords**
  - [ ] BCrypt with proper cost factor (12+)
  - [ ] No password in logs or error messages
  - [ ] Password complexity requirements enforced

- [ ] **Sensitive Data**
  - [ ] API keys encrypted at rest
  - [ ] Database encryption for PII
  - [ ] HTTPS enforced in production
  - [ ] TLS 1.2+ only

- [ ] **Environment Variables**
  - [ ] All secrets in environment variables
  - [ ] `.env` file in `.gitignore`
  - [ ] No secrets in git history
  - [ ] Different secrets per environment

- [ ] **Tests**
  ```bash
  # Check for exposed secrets
  git log -p | grep -i "api_key\|secret\|password" | grep "+"

  # Scan for secrets in code
  docker run --rm -v $(pwd):/src trufflesecurity/trufflehog:latest \
    git file:///src --only-verified
  ```

## A03:2021 – Injection

### SQL Injection

- [ ] **ActiveRecord Queries**
  - [ ] No string interpolation in queries
  - [ ] Parameterized queries only
  - [ ] `.where(id: params[:id])` NOT `.where("id = #{params[:id]}")`
  - [ ] Review all raw SQL queries

- [ ] **Vulnerable Patterns**
  ```ruby
  # ❌ VULNERABLE
  Player.where("name = '#{params[:name]}'")
  Player.find_by_sql("SELECT * FROM players WHERE id = #{params[:id]}")

  # ✅ SAFE
  Player.where(name: params[:name])
  Player.find_by_sql(["SELECT * FROM players WHERE id = ?", params[:id]])
  ```

- [ ] **Command Injection**
  - [ ] No `system()`, `exec()`, backticks with user input
  - [ ] If shell commands needed, use `Open3.capture3` with whitelisting

- [ ] **Tests**
  ```bash
  # ZAP API scan includes injection tests
  ./security_tests/scripts/zap-api-scan.sh

  # Manual SQL injection test
  curl -X GET "http://localhost:3333/api/v1/players?name=admin'%20OR%20'1'='1"
  # Should NOT return data or error with SQL
  ```

## A04:2021 – Insecure Design

### Architecture Security

- [ ] **Rate Limiting**
  - [ ] Rack::Attack configured
  - [ ] Login endpoint throttled
  - [ ] API endpoints rate limited per user/IP
  - [ ] Exponential backoff on failed attempts

- [ ] **Input Validation**
  - [ ] Strong parameters in all controllers
  - [ ] Data type validation
  - [ ] Length limits on strings
  - [ ] Regex validation where needed

- [ ] **Business Logic**
  - [ ] State transitions validated
  - [ ] No race conditions in critical operations
  - [ ] Idempotency for mutations
  - [ ] Transaction locks where needed

- [ ] **Tests**
  ```bash
  # Rate limiting test
  for i in {1..100}; do
    curl -X POST http://localhost:3333/api/v1/auth/login \
      -d '{"email":"test@test.com","password":"wrong"}' &
  done
  # Should eventually return 429 Too Many Requests
  ```

## A05:2021 – Security Misconfiguration

### Configuration Security

- [ ] **Rails Configuration**
  - [ ] `config.force_ssl = true` in production
  - [ ] Debug mode disabled in production
  - [ ] Detailed error pages disabled in production
  - [ ] Asset host configured for CDN

- [ ] **Headers**
  - [ ] `X-Frame-Options: DENY`
  - [ ] `X-Content-Type-Options: nosniff`
  - [ ] `X-XSS-Protection: 1; mode=block`
  - [ ] `Strict-Transport-Security: max-age=31536000`
  - [ ] `Content-Security-Policy` configured
  - [ ] `Referrer-Policy: strict-origin-when-cross-origin`

- [ ] **CORS**
  - [ ] Whitelist specific origins, not `*`
  - [ ] Credentials allowed only for trusted origins
  - [ ] Proper preflight handling

- [ ] **Dependencies**
  - [ ] All gems up to date
  - [ ] No known vulnerabilities
  - [ ] Unused gems removed

- [ ] **Tests**
  ```bash
  # Security headers check
  curl -I http://localhost:3333/up | grep -E "X-Frame-Options|X-Content-Type"

  # Dependency check
  ./security_tests/scripts/dependency-scan.sh

  # Brakeman scan
  ./security_tests/scripts/brakeman-scan.sh
  ```

## A06:2021 – Vulnerable and Outdated Components

### Dependency Management

- [ ] **Monitoring**
  - [ ] Dependabot enabled
  - [ ] Bundle audit in CI/CD
  - [ ] Monthly dependency review

- [ ] **Update Process**
  - [ ] Security patches applied ASAP
  - [ ] Test suite run before updates
  - [ ] Changelog reviewed

- [ ] **Tests**
  ```bash
  # Check for vulnerabilities
  bundle audit check --update

  # List outdated gems
  bundle outdated

  # OWASP Dependency Check
  docker run --rm -v $(pwd):/src owasp/dependency-check:latest \
    --scan /src --format ALL
  ```

## A07:2021 – Identification and Authentication Failures

### Authentication Security

- [ ] **Password Security**
  - [ ] Minimum 8 characters
  - [ ] Complexity requirements
  - [ ] No common passwords (have_i_been_pwned check)
  - [ ] Bcrypt cost factor 12+

- [ ] **Session Management**
  - [ ] JWT expiration (15 min access, 7 day refresh)
  - [ ] Secure session storage (Redis)
  - [ ] Session invalidation on logout
  - [ ] Session timeout after inactivity

- [ ] **Multi-Factor Authentication (Future)**
  - [ ] TOTP support
  - [ ] Backup codes
  - [ ] SMS fallback

- [ ] **Account Recovery**
  - [ ] Secure password reset flow
  - [ ] Time-limited reset tokens
  - [ ] Email verification
  - [ ] Rate limited reset requests

- [ ] **Tests**
  ```bash
  # Weak password test
  curl -X POST http://localhost:3333/api/v1/auth/register \
    -H "Content-Type: application/json" \
    -d '{"email":"test@test.com","password":"123"}'
  # Should be rejected

  # Token expiration test
  # Use old token after 15+ minutes
  curl -H "Authorization: Bearer EXPIRED_TOKEN" \
       http://localhost:3333/api/v1/dashboard
  # Should return 401
  ```

## A08:2021 – Software and Data Integrity Failures

### Code Integrity

- [ ] **CI/CD Security**
  - [ ] Signed commits
  - [ ] Code review required
  - [ ] Branch protection
  - [ ] Automated tests pass

- [ ] **Serialization**
  - [ ] No unsafe deserialization
  - [ ] JSON parsing only
  - [ ] No YAML.load (use YAML.safe_load)
  - [ ] No Marshal.load on user input

- [ ] **Auto-updates**
  - [ ] Review before auto-merge
  - [ ] Test auto-updated dependencies
  - [ ] Pin critical dependencies

- [ ] **Tests**
  ```bash
  # Check for unsafe deserialization
  grep -r "Marshal.load\|YAML.load" app/

  # Should use safe alternatives
  grep -r "YAML.safe_load" app/
  ```

## A09:2021 – Security Logging and Monitoring Failures

### Logging & Monitoring

- [ ] **Application Logs**
  - [ ] Authentication attempts logged
  - [ ] Authorization failures logged
  - [ ] Sensitive operations logged
  - [ ] No sensitive data in logs (passwords, tokens)

- [ ] **Audit Trail**
  - [ ] AuditLog model tracks changes
  - [ ] Who, what, when recorded
  - [ ] IP address logged
  - [ ] Tamper-proof logs

- [ ] **Monitoring**
  - [ ] Error tracking (Sentry/Rollbar)
  - [ ] Performance monitoring (New Relic/Scout)
  - [ ] Uptime monitoring
  - [ ] Alert on suspicious activity

- [ ] **Tests**
  ```bash
  # Check logs don't contain secrets
  grep -r "password\|token\|secret" log/ | grep -v "filtered"

  # Verify audit logging
  rails console
  > AuditLog.where(action: 'update').last
  # Should show recent changes
  ```

## A10:2021 – Server-Side Request Forgery (SSRF)

### External Requests

- [ ] **Riot API Integration**
  - [ ] URL validation before requests
  - [ ] Whitelist allowed domains
  - [ ] No user-controlled URLs
  - [ ] Timeout on external requests

- [ ] **URL Validation**
  ```ruby
  # ✅ SAFE
  ALLOWED_HOSTS = ['americas.api.riotgames.com', 'europe.api.riotgames.com']
  url = URI.parse(riot_api_url)
  raise unless ALLOWED_HOSTS.include?(url.host)

  # ❌ VULNERABLE
  url = params[:callback_url]
  HTTP.get(url) # User could access internal services
  ```

- [ ] **Internal Service Protection**
  - [ ] No access to localhost
  - [ ] No access to private IPs (192.168.*, 10.*, 127.*)
  - [ ] No access to metadata endpoints (169.254.169.254)

- [ ] **Tests**
  ```bash
  # Try SSRF via webhook/callback
  curl -X POST http://localhost:3333/api/v1/webhooks \
    -d '{"url":"http://localhost:6379"}'
  # Should be rejected

  # Try cloud metadata access
  curl -X POST http://localhost:3333/api/v1/webhooks \
    -d '{"url":"http://169.254.169.254/latest/meta-data/"}'
  # Should be rejected
  ```

---

## Automated Security Testing

### Run Full Security Audit

```bash
# Complete security audit (all tools)
./security_tests/scripts/full-security-audit.sh

# Individual scans
./security_tests/scripts/brakeman-scan.sh
./security_tests/scripts/dependency-scan.sh
./security_tests/scripts/zap-baseline-scan.sh
./security_tests/scripts/zap-api-scan.sh
```

### Pre-Production Checklist

Before deploying to production:

1. [ ] All OWASP Top 10 items reviewed
2. [ ] Full security audit run
3. [ ] All critical/high issues fixed
4. [ ] Penetration test completed
5. [ ] Security headers configured
6. [ ] Rate limiting enabled
7. [ ] Monitoring & alerts configured
8. [ ] Incident response plan documented
9. [ ] Backup & recovery tested
10. [ ] Security training for team

---

## Continuous Security

### Weekly
- [ ] Review security logs
- [ ] Check for new vulnerabilities
- [ ] Monitor failed auth attempts

### Monthly
- [ ] Run full security audit
- [ ] Update dependencies
- [ ] Review access controls
- [ ] Penetration testing

### Quarterly
- [ ] Security code review
- [ ] Third-party security audit
- [ ] Update security documentation
- [ ] Team security training

---

**Last Updated:** $(date)
**Next Review:** $(date -d "+1 month" 2>/dev/null || date -v +1m)
