import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';
import { config, getAuthToken, authHeaders } from '../config.js';

const errorRate = new Rate('errors');

export const options = {
  ...config.profiles.smoke,
  ext: {
    loadimpact: {
      name: 'ProStaff API - Smoke Test'
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

  // Test 1: Health check
  const healthRes = http.get(`${config.baseUrl}/up`);
  check(healthRes, {
    'health check is 200': (r) => r.status === 200,
  }) || errorRate.add(1);

  sleep(1);

  // Test 2: Dashboard stats (cached endpoint)
  const dashboardRes = http.get(
    `${config.baseUrl}${config.endpoints.dashboard.stats}`,
    { headers }
  );
  check(dashboardRes, {
    'dashboard stats is 200': (r) => r.status === 200,
    'dashboard stats has data': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.data !== undefined;
      } catch {
        return false;
      }
    }
  }) || errorRate.add(1);

  sleep(1);

  // Test 3: Players list (basic query)
  const playersRes = http.get(
    `${config.baseUrl}${config.endpoints.players.list}`,
    { headers }
  );
  check(playersRes, {
    'players list is 200': (r) => r.status === 200,
    'players list returns array': (r) => {
      try {
        const body = JSON.parse(r.body);
        // API returns {data: {players: []}}
        return Array.isArray(body?.data?.players) || Array.isArray(body?.data) || Array.isArray(body);
      } catch {
        return false;
      }
    }
  }) || errorRate.add(1);

  sleep(2);
}

export function teardown(data) {
  console.log('Smoke test completed');
}
