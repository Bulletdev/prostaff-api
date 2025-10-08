import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';
import { config, getAuthToken, authHeaders } from '../config.js';

const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');

export const options = {
  ...config.profiles.stress,
  ext: {
    loadimpact: {
      name: 'ProStaff API - Stress Test'
    }
  }
};

export function setup() {
  const token = getAuthToken(http);
  if (!token) {
    throw new Error('Failed to get auth token in setup');
  }
  return { token };
}

// Aggressive test - minimal sleep, max endpoints
export default function(data) {
  const headers = authHeaders(data.token);

  group('Heavy Dashboard Load', () => {
    const responses = http.batch([
      ['GET', `${config.baseUrl}${config.endpoints.dashboard.index}`, null, { headers }],
      ['GET', `${config.baseUrl}${config.endpoints.dashboard.stats}`, null, { headers }],
      ['GET', `${config.baseUrl}${config.endpoints.dashboard.activities}`, null, { headers }],
      ['GET', `${config.baseUrl}${config.endpoints.dashboard.schedule}`, null, { headers }],
    ]);

    responses.forEach((res, index) => {
      responseTime.add(res.timings.duration);
      check(res, {
        [`batch request ${index} successful`]: (r) => r.status === 200,
        [`batch request ${index} fast enough`]: (r) => r.timings.duration < 3000,
      }) || errorRate.add(1);
    });
  });

  sleep(0.5);

  group('Heavy Analytics Load', () => {
    const perfRes = http.get(
      `${config.baseUrl}${config.endpoints.analytics.performance}?start_date=2024-01-01&end_date=2025-12-31`,
      { headers }
    );

    responseTime.add(perfRes.timings.duration);
    check(perfRes, {
      'heavy analytics query successful': (r) => r.status === 200,
      'heavy analytics query completes': (r) => r.timings.duration < 5000,
    }) || errorRate.add(1);
  });

  sleep(0.5);

  group('Database Stress', () => {
    const dbStress = http.batch([
      ['GET', `${config.baseUrl}${config.endpoints.players.list}`, null, { headers }],
      ['GET', `${config.baseUrl}${config.endpoints.matches.list}`, null, { headers }],
      ['GET', `${config.baseUrl}${config.endpoints.players.stats}`, null, { headers }],
    ]);

    dbStress.forEach((res, index) => {
      responseTime.add(res.timings.duration);
      check(res, {
        [`db stress ${index} successful`]: (r) => r.status === 200,
      }) || errorRate.add(1);
    });
  });

  sleep(0.3);
}

export function teardown(data) {
  console.log('Stress test completed - check for breaking points');
}
