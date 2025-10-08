import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';
import { config, getAuthToken, authHeaders } from '../config.js';

const errorRate = new Rate('errors');
const spikeDuration = new Trend('spike_response_time');

export const options = {
  ...config.profiles.spike,
  ext: {
    loadimpact: {
      name: 'ProStaff API - Spike Test'
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

export default function(data) {
  const headers = authHeaders(data.token);

  group('Spike Scenario - Heavy Dashboard Access', () => {
    const start = Date.now();

    const dashRes = http.get(
      `${config.baseUrl}${config.endpoints.dashboard.index}`,
      { headers }
    );

    spikeDuration.add(Date.now() - start);

    check(dashRes, {
      'dashboard survived spike': (r) => r.status === 200,
      'dashboard response during spike': (r) => r.timings.duration < 5000,
    }) || errorRate.add(1);

    sleep(0.2);

    if (Math.random() < 0.5) {
      const statsRes = http.get(
        `${config.baseUrl}${config.endpoints.dashboard.stats}`,
        { headers }
      );

      check(statsRes, {
        'stats available during spike': (r) => r.status === 200,
      }) || errorRate.add(1);
    }
  });

  sleep(0.5);
}

export function teardown(data) {
  console.log('Spike test completed - check recovery time and error rates');
}
