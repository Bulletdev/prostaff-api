# ProStaff API - Load & Stress Testing

Comprehensive load testing suite using k6 to measure API performance, identify bottlenecks, and determine if GraphQL is needed.

## 🎯 Objectives

1. **Baseline Performance**: Establish current API performance metrics
2. **Identify Bottlenecks**: Find slow endpoints and N+1 query issues
3. **Breaking Points**: Determine max capacity before degradation
4. **GraphQL Decision**: Data to support REST vs GraphQL decision

## 📦 Setup

### Install k6

```bash
./load_tests/k6-setup.sh
```

Or manually:
- **Linux**: `sudo apt-get install k6`
- **macOS**: `brew install k6`
- **Windows**: `choco install k6`

### Configure Test User

Create test user in your database or use existing credentials:

```bash
# In .env file
TEST_EMAIL=test@prostaff.gg
TEST_PASSWORD=Test123!@#
```

## 🧪 Test Scenarios

### 1. Smoke Test (1 min)
**Purpose**: Quick sanity check, minimal load

```bash
./load_tests/run-tests.sh smoke local
```

**Profile**:
- 1 virtual user
- Tests basic endpoints
- Validates setup

### 2. Load Test (16 min)
**Purpose**: Normal traffic simulation

```bash
./load_tests/run-tests.sh load local
```

**Profile**:
- Ramps 0 → 10 → 50 users
- Realistic user workflows
- 95th percentile < 1s

**Use Cases**:
- Dashboard browsing (60%)
- Analytics review (30%)
- Player management (10%)

### 3. Stress Test (28 min)
**Purpose**: Find breaking point

```bash
./load_tests/run-tests.sh stress local
```

**Profile**:
- Ramps 0 → 50 → 100 → 200 → 300 users
- Aggressive querying
- Tests DB connection pool, Redis, memory

### 4. Spike Test (7.5 min)
**Purpose**: Sudden traffic surge (e.g., tournament announcement)

```bash
./load_tests/run-tests.sh spike local
```

**Profile**:
- Instant jump: 10 → 500 users
- Tests auto-scaling, caching
- Measures recovery time

### 5. Soak Test (3+ hours)
**Purpose**: Long-term stability, memory leaks

```bash
./load_tests/run-tests.sh soak local
```

**Profile**:
- 50 concurrent users for 3 hours
- Monitors degradation over time
- Detects memory leaks, connection pool issues

## 📊 Interpreting Results

### Key Metrics

**Response Times**:
- `http_req_duration`: Total request time
- `http_req_waiting`: Time to first byte (TTFB)
- p(95) < 1000ms ✅ Good
- p(95) > 2000ms ⚠️ Issue

**Throughput**:
- `http_reqs`: Total requests
- `iterations`: Complete user workflows
- Higher is better

**Errors**:
- `http_req_failed`: Failed requests
- < 1% ✅ Acceptable
- > 5% ❌ Critical issue

**Custom Metrics**:
- `dashboard_duration`: Dashboard load time
- `analytics_duration`: Analytics query time
- `errors`: Error rate

### Results Location

```
load_tests/results/
├── smoke_20250107_120000/
│   ├── results.json       # Full metrics
│   ├── summary.json       # Aggregated stats
│   └── output.log         # Console output
```

### Reading Summary

```bash
# View key metrics
jq '.metrics.http_req_duration' results/smoke_*/summary.json

# Check error rate
jq '.metrics.http_req_failed.values.rate' results/smoke_*/summary.json

# Response time percentiles
jq '.metrics.http_req_duration.values' results/smoke_*/summary.json
```

## 🎯 GraphQL Decision Framework

Run all tests and analyze:

### ✅ GraphQL Makes Sense If:

1. **Multiple Roundtrips**
   - Load test shows many sequential API calls
   - Frontend makes 5+ requests per page
   - High `http_reqs` count for simple workflows

2. **Overfetching**
   - Large payload sizes (> 100KB for simple data)
   - Unused fields in responses
   - Bandwidth issues in metrics

3. **Complex Queries**
   - Dashboard/analytics endpoints timeout
   - N+1 query issues visible in logs
   - High `http_req_waiting` times

4. **Multiple Clients**
   - Different needs (web/mobile/partners)
   - Custom views per client
   - Version management pain

### ❌ Stick with REST If:

1. **Good Performance**
   - All p(95) < 500ms
   - Error rate < 1%
   - No timeout issues

2. **Simple Data Needs**
   - 1-2 API calls per workflow
   - Payloads reasonable (< 50KB)
   - No overfetching

3. **Small Team**
   - Learning curve not worth it
   - Complexity > benefit
   - Current system maintainable

## 🚀 Running Against Environments

### Local
```bash
./load_tests/run-tests.sh load local
```

### Staging
```bash
./load_tests/run-tests.sh load staging
```

### Production (⚠️ CAREFUL!)
```bash
# Only run smoke/load tests, NOT stress
./load_tests/run-tests.sh smoke production
./load_tests/run-tests.sh load production
```

**Never run stress/spike/soak against production!**

## 🔍 Analyzing Bottlenecks

### Slow Endpoints

Look for high `http_req_duration` on specific endpoints:

```javascript
// In k6 output
✓ dashboard loaded
  ├─ avg=1250ms  // ⚠️ Slow!
  ├─ p(95)=2500ms

✓ players list loaded
  ├─ avg=150ms   // ✅ Fast
  ├─ p(95)=300ms
```

**Actions**:
1. Check Rails logs for N+1 queries
2. Add database indexes
3. Implement caching
4. Consider pagination

### Database Issues

Symptoms:
- Errors during stress test
- `http_req_failed` increases with load
- 500/503 errors in logs

**Check**:
```bash
# In Rails logs during test
tail -f log/development.log | grep -E '(timeout|connection|pool)'
```

**Solutions**:
- Increase DB connection pool
- Add read replicas
- Optimize slow queries

### Memory Leaks

Run soak test and monitor:

```bash
# During soak test
docker stats prostaff-api  # If using Docker
# Or
top -p $(pgrep -f puma)
```

**Red flags**:
- Memory usage climbing over time
- OOM errors after hours
- Response time degradation

## 📈 Continuous Testing

### Pre-deployment Checklist

```bash
# Before each release
./load_tests/run-tests.sh smoke staging
./load_tests/run-tests.sh load staging

# If performance-critical changes
./load_tests/run-tests.sh stress staging
```

### CI/CD Integration

See `.github/workflows/load-test.yml` (if configured)

## 🔧 Advanced Usage

### Custom Scenarios

Create your own test in `scenarios/`:

```javascript
import { config } from '../config.js';

export const options = {
  stages: [
    { duration: '5m', target: 100 },
  ],
};

export default function() {
  // Your test logic
}
```

### Environment Variables

```bash
# Custom configuration
BASE_URL=http://localhost:3000 \
TEST_EMAIL=custom@email.com \
./load_tests/run-tests.sh load local
```

### Output Formats

```bash
# CSV output
k6 run --out csv=results.csv scenarios/load-test.js

# InfluxDB (time-series analysis)
k6 run --out influxdb=http://localhost:8086/k6 scenarios/load-test.js
```

## 📚 Resources

- [k6 Documentation](https://k6.io/docs/)
- [Load Testing Best Practices](https://k6.io/docs/testing-guides/test-types/)
- [Interpreting Results](https://k6.io/docs/using-k6/metrics/)

## 🎓 Next Steps

1. ✅ Run smoke test to validate setup
2. ✅ Run load test to baseline performance
3. ✅ Identify slow endpoints from results
4. ✅ Optimize bottlenecks
5. ✅ Re-run tests to measure improvement
6. ✅ Make REST vs GraphQL decision based on data
