import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import { config, getAuthToken, authHeaders } from '../config.js';

// Custom metrics to track degradation over time
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');
const memoryErrors = new Counter('memory_errors');
const timeouts = new Counter('timeouts');

export const options = {
  ...config.profiles.soak,
  ext: {
    loadimpact: {
      name: 'ProStaff API - Soak Test (3h sustained load)'
    }
  }
};

export function setup() {
  const token = getAuthToken(http);
  if (!token) {
    throw new Error('Failed to get auth token in setup');
  }
  console.log('Starting 3-hour soak test - monitoring for memory leaks and degradation');
  return { token, startTime: Date.now() };
}

export default function(data) {
  const headers = authHeaders(data.token);
  const elapsed = (Date.now() - data.startTime) / 1000 / 60; // minutes

  group('Sustained Load Pattern', () => {
    const workflows = [
      () => {
        const res = http.get(
          `${config.baseUrl}${config.endpoints.dashboard.index}`,
          { headers, timeout: '30s' }
        );
        return { name: 'dashboard', res };
      },
      () => {
        const res = http.get(
          `${config.baseUrl}${config.endpoints.analytics.performance}`,
          { headers, timeout: '30s' }
        );
        return { name: 'analytics', res };
      },
      () => {
        const res = http.get(
          `${config.baseUrl}${config.endpoints.players.list}`,
          { headers, timeout: '30s' }
        );
        return { name: 'players', res };
      }
    ];

    const workflow = workflows[Math.floor(Math.random() * workflows.length)];
    const result = workflow();

    responseTime.add(result.res.timings.duration);

    const success = check(result.res, {
      [`${result.name} - status OK`]: (r) => r.status === 200,
      [`${result.name} - no timeout`]: (r) => r.status !== 0,
      [`${result.name} - reasonable time`]: (r) => r.timings.duration < 3000,
    });

    if (!success) {
      errorRate.add(1);
      if (result.res.status === 0) {
        timeouts.add(1);
      }
      if (result.res.status === 500 || result.res.status === 503) {
        memoryErrors.add(1);
      }
    }

    if (elapsed > 0 && elapsed % 30 < 0.1) {
      console.log(`Soak test progress: ${Math.floor(elapsed)} minutes elapsed`);
    }
  });

  sleep(Math.random() * 10 + 5);
}

export function teardown(data) {
  const duration = (Date.now() - data.startTime) / 1000 / 60;
  console.log(`Soak test completed after ${Math.floor(duration)} minutes`);
  console.log('Check metrics for:');
  console.log('- Response time degradation over time');
  console.log('- Memory leak indicators (500/503 errors increasing)');
  console.log('- Database connection pool exhaustion');
  console.log('- Redis connection issues');
}
