# ProStaff API - Testing & Security Guide

Complete guide for load testing and security testing your ProStaff API.

##  Table of Contents

- [Quick Start](#quick-start)
- [Load Testing](#load-testing)
- [Security Testing](#security-testing)
- [CI/CD Integration](#cicd-integration)
- [GraphQL Decision Framework](#graphql-decision-framework)
- [Runbooks](#runbooks)

##  Quick Start

### Prerequisites

```bash
# Install k6 for load testing
./load_tests/k6-setup.sh

# Setup security lab
./security_tests/zap-setup.sh
```

### Run Complete Test Suite

```bash
# 1. Start your Rails server
bundle exec rails server

# 2. Run load tests (in another terminal)
./load_tests/run-tests.sh smoke local
./load_tests/run-tests.sh load local

# 3. Run security audit
./security_tests/scripts/full-security-audit.sh
```

## 📊 Load Testing

Comprehensive performance testing to evaluate if GraphQL is needed.

### Test Types

| Test | Duration | Purpose | When to Run |
|------|----------|---------|-------------|
| **Smoke** | 1 min | Quick validation | Every commit |
| **Load** | 16 min | Normal traffic simulation | Before merge |
| **Stress** | 28 min | Find breaking points | Weekly |
| **Spike** | 7.5 min | Sudden surge handling | Before release |
| **Soak** | 3+ hours | Memory leaks | Monthly |

### Running Tests

```bash
# Local testing
./load_tests/run-tests.sh [test-type] local

# Staging
./load_tests/run-tests.sh load staging

# Production (CAREFUL!)
./load_tests/run-tests.sh smoke production  # Only smoke/load, never stress!
```

### Interpreting Results

**Good Performance (Stick with REST):**
```
✅ http_req_duration p(95) < 500ms
✅ http_req_failed < 1%
✅ No timeouts
```

**Consider GraphQL If:**
```
⚠️ Multiple sequential requests per page (5+)
⚠️ Overfetching (large unused payloads)
⚠️ Dashboard/analytics endpoints timing out
⚠️ N+1 query issues visible
```

**Detailed Guide**: [load_tests/README.md](load_tests/README.md)

## 🔒 Security Testing

Continuous security validation following OWASP Top 10.

### Quick Security Scan

```bash
# Individual scans
./security_tests/scripts/brakeman-scan.sh          # Code analysis
./security_tests/scripts/dependency-scan.sh        # Gem vulnerabilities
./security_tests/scripts/zap-baseline-scan.sh      # Web app scan

# Complete audit
./security_tests/scripts/full-security-audit.sh
```

### OWASP Top 10 Checklist

Interactive checklist: [security_tests/OWASP_TOP_10_CHECKLIST.md](security_tests/OWASP_TOP_10_CHECKLIST.md)

**Before Production:**
- [ ] All critical/high Brakeman issues fixed
- [ ] No vulnerable dependencies
- [ ] Security headers configured
- [ ] Rate limiting enabled
- [ ] Authentication tested
- [ ] Authorization tested (IDOR prevention)
- [ ] Input validation working
- [ ] CSRF protection active
- [ ] Secrets not in code/git
- [ ] Full security audit passed

### Security Tools

| Tool | Purpose | Frequency |
|------|---------|-----------|
| **Brakeman** | Rails code security | Every commit (CI/CD) |
| **Bundle Audit** | Gem vulnerabilities | Daily |
| **OWASP ZAP** | Runtime security | Weekly |
| **Semgrep** | Static analysis | Every PR |
| **TruffleHog** | Secret detection | Every commit |

**Detailed Guide**: [security_tests/README.md](security_tests/README.md)

##  CI/CD Integration

Automated testing in your GitHub Actions workflows.

### Workflows

**1. Security Scan** (`.github/workflows/security-scan.yml`)
- Runs on: Every push, PR, weekly schedule
- Checks: Brakeman, dependencies, Semgrep, secrets
- Fails PR if critical issues found

**2. Load Test** (`.github/workflows/load-test.yml`)
- Runs on: Manual trigger, nightly schedule
- Tests: Smoke test nightly, custom on demand
- Reports: Performance metrics and trends

**3. Nightly Security Audit** (`.github/workflows/nightly-security.yml`)
- Runs on: Every night at 1am UTC
- Complete: Full security audit with ZAP
- Alerts: Creates GitHub issue if vulnerabilities found

### Enabling Workflows

1. **Add Secrets** to GitHub repository:
   ```
   Settings → Secrets → Actions

   TEST_EMAIL=test@prostaff.gg
   TEST_PASSWORD=your-test-password
   ```

2. **Workflows automatically run** on:
   - Push to master/develop
   - Pull requests
   - Scheduled times
   - Manual trigger

### Manual Trigger

```bash
# Via GitHub UI
Actions → [Workflow Name] → Run workflow

# Via GitHub CLI
gh workflow run load-test.yml \
  -f test_type=load \
  -f environment=staging
```

## 📈 GraphQL Decision Framework

Use load testing results to make data-driven decision.

### Run This Analysis

```bash
# 1. Baseline current performance
./load_tests/run-tests.sh load local

# 2. Check results
cat load_tests/results/load_*/summary.json | jq '.metrics.http_req_duration.values'

# 3. Monitor API calls per page
# In browser DevTools Network tab, count requests for:
#   - Dashboard page
#   - Analytics page
#   - Player detail page

# 4. Check payload sizes
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:3333/api/v1/dashboard \
     -w '\nSize: %{size_download} bytes\n'
```

### Decision Matrix

** GraphQL is Worth It If:**

| Criteria | Evidence |
|----------|----------|
| Multiple clients | Web + Mobile + Partners API |
| Many roundtrips | 5+ API calls per page load |
| Overfetching | Payloads > 100KB with unused data |
| Complex queries | Dashboard p(95) > 2s |
| Team experience | Team knows GraphQL well |

** Stick with REST If:**

| Criteria | Evidence |
|----------|----------|
| Good performance | p(95) < 500ms on all endpoints |
| Simple needs | 1-2 API calls per workflow |
| Small team | Learning curve > benefit |
| Reasonable payloads | < 50KB, minimal waste |
| Working well | No complaints, fast enough |

### Hybrid Approach

If you're on the fence:

1. **Keep REST for CRUD**
   - Simple player/match operations
   - Single-resource endpoints

2. **Add GraphQL for Analytics**
   - Dashboard aggregations
   - Complex reports
   - Flexible queries

3. **Implement Gradually**
   ```ruby
   # Add to Gemfile
   gem 'graphql'

   # Mount alongside REST
   # config/routes.rb
   post '/graphql', to: 'graphql#execute'
   ```

##  Runbooks

### Runbook 1: Weekly Security Check

**When**: Every Monday morning
**Duration**: 15 minutes

```bash
# 1. Check for dependency vulnerabilities
./security_tests/scripts/dependency-scan.sh

# 2. Update vulnerable gems
bundle update [gem-name]

# 3. Run tests
bundle exec rspec

# 4. Run Brakeman
./security_tests/scripts/brakeman-scan.sh

# 5. Review and fix issues
open security_tests/reports/brakeman/brakeman-*.html

# 6. Commit fixes
git commit -am "security: update dependencies and fix issues"
```

### Runbook 2: Pre-Release Testing

**When**: Before each production deployment
**Duration**: 30-60 minutes

```bash
# 1. Deploy to staging
git push staging master

# 2. Wait for deployment
# Check staging URL is live

# 3. Run smoke test
./load_tests/run-tests.sh smoke staging

# 4. Run full security audit
./security_tests/scripts/full-security-audit.sh https://staging-api.prostaff.gg

# 5. Review results
ls -la security_tests/reports/audit-*/

# 6. Fix critical issues if any
# Re-run tests

# 7. If all pass, deploy to production
git push production master

# 8. Run production smoke test
./load_tests/run-tests.sh smoke production

# 9. Monitor logs and metrics
tail -f log/production.log
```

### Runbook 3: Security Incident Response

**When**: Vulnerability discovered
**Duration**: Varies by severity

#### Critical/High Severity

```bash
# 1. ASSESS (5 min)
- What is affected?
- How many users?
- Is it being exploited?

# 2. CONTAIN (15 min)
- Disable affected endpoint/feature
- Add WAF rule if available
- Notify team

# 3. FIX (varies)
- Develop patch
- Test thoroughly
- Code review

# 4. DEPLOY (15 min)
- Emergency deployment process
- Skip non-critical checks
- Deploy fix

# 5. VERIFY (10 min)
- Confirm fix works
- Run security scan
- Check logs for exploitation

# 6. COMMUNICATE (30 min)
- Notify affected users
- Post-mortem
- Update documentation

# 7. PREVENT (ongoing)
- Add automated test
- Update security checklist
- Team training
```

#### Medium/Low Severity

```bash
# 1. Document issue
- Create GitHub issue
- Add to backlog
- Assign severity label

# 2. Schedule fix
- Include in next sprint
- Not emergency

# 3. Fix and deploy
- Normal development process
- Include in next release

# 4. Verify fix
- Run security tests
- Close issue
```

### Runbook 4: Performance Issue Investigation

**When**: Load test fails or production slow
**Duration**: 1-2 hours

```bash
# 1. REPRODUCE
./load_tests/run-tests.sh load staging
# Note which endpoints are slow

# 2. CHECK LOGS
tail -f log/development.log | grep "Completed 200"
# Look for slow queries (> 100ms)

# 3. IDENTIFY N+1 QUERIES
# In Rails console
ActiveRecord::Base.logger = Logger.new(STDOUT)
# Run problematic endpoint logic

# 4. CHECK DATABASE
# Open Rails dbconsole
\d+ players  # Check indexes
EXPLAIN ANALYZE SELECT ...  # Analyze slow query

# 5. PROFILE CODE
# Add to Gemfile
gem 'rack-mini-profiler'
# Visit slow endpoint, check flamegraph

# 6. COMMON FIXES
# Add eager loading
Player.includes(:champion_pools, :matches)

# Add database index
rails g migration AddIndexToPlayersOnOrganizationId
add_index :players, :organization_id

# Add caching
Rails.cache.fetch("dashboard_stats_#{org.id}", expires_in: 5.minutes) do
  calculate_stats
end

# 7. VERIFY FIX
./load_tests/run-tests.sh load local
# Compare before/after metrics

# 8. DEPLOY
# Normal deployment process
```

### Runbook 5: Monthly Security Review

**When**: First of each month
**Duration**: 2-3 hours

```bash
# 1. Run comprehensive tests
./security_tests/scripts/full-security-audit.sh

# 2. Review all reports
open security_tests/reports/audit-*/

# 3. Check access logs
# Look for suspicious patterns
grep "401\|403\|429" log/production.log | tail -100

# 4. Review audit logs
rails console production
> AuditLog.where("created_at > ?", 1.month.ago).where(action: 'failed_login').count

# 5. Update dependencies
bundle update --patch
bundle update --minor (if safe)

# 6. Review OWASP checklist
# Go through OWASP_TOP_10_CHECKLIST.md
# Check all items

# 7. Team security training
# Schedule 30min session
# Review recent issues
# Share best practices

# 8. Update documentation
# Any new security measures?
# Update runbooks if needed

# 9. Report to leadership
# Create summary report
# Highlight any concerns
# Request resources if needed
```

## 🎓 Best Practices

### Development
- ✅ Run Brakeman before each commit
- ✅ Review security scan results in PRs
- ✅ Never commit secrets
- ✅ Use strong parameters
- ✅ Test authorization (not just authentication)

### Testing
- ✅ Run smoke tests before each PR
- ✅ Run load tests before releases
- ✅ Security audit before production deploy
- ✅ Monitor performance trends

### Production
- ✅ Security headers enabled
- ✅ Rate limiting active
- ✅ Error tracking configured
- ✅ Logs monitored
- ✅ Alerts set up

### Continuous Improvement
- ✅ Monthly security reviews
- ✅ Weekly dependency updates
- ✅ Quarterly penetration tests
- ✅ Team security training

## 📚 Additional Resources

- [Load Testing Guide](load_tests/README.md)
- [Security Testing Guide](security_tests/README.md)
- [OWASP Top 10 Checklist](security_tests/OWASP_TOP_10_CHECKLIST.md)
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)
- [k6 Documentation](https://k6.io/docs/)
- [OWASP ZAP User Guide](https://www.zaproxy.org/docs/)

## 🆘 Need Help?

**Security Issues**: Report privately to security team
**Performance Issues**: Create GitHub issue with load test results
**Tool Problems**: Check tool documentation or create issue

---

**Last Updated**: $(date)
**Maintained By**: Security & Performance Team
