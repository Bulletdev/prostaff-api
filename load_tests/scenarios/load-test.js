import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import { config, getAuthToken, authHeaders } from '../config.js';

const errorRate = new Rate('errors');
const dashboardDuration = new Trend('dashboard_duration');
const analyticsDuration = new Trend('analytics_duration');
const apiCalls = new Counter('api_calls');

export const options = {
  ...config.profiles.load,
  ext: {
    loadimpact: {
      name: 'ProStaff API - Load Test'
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

// Main test - simulates realistic user behavior
export default function(data) {
  const headers = authHeaders(data.token);

  // Scenario 1: Dashboard workflow (60% of users)
  if (Math.random() < 0.6) {
    group('Dashboard Workflow', () => {
      const dashStart = Date.now();
      const dashRes = http.get(
        `${config.baseUrl}${config.endpoints.dashboard.index}`,
        { headers }
      );
      dashboardDuration.add(Date.now() - dashStart);
      apiCalls.add(1);

      check(dashRes, {
        'dashboard loaded': (r) => r.status === 200,
        'dashboard response time OK': (r) => r.timings.duration < 2000,
      }) || errorRate.add(1);

      sleep(2);

      const activitiesRes = http.get(
        `${config.baseUrl}${config.endpoints.dashboard.activities}`,
        { headers }
      );
      apiCalls.add(1);

      check(activitiesRes, {
        'activities loaded': (r) => r.status === 200,
      }) || errorRate.add(1);

      sleep(3);
    });
  }

  // Scenario 2: Analytics workflow (30% of users)
  else if (Math.random() < 0.75) {
    group('Analytics Workflow', () => {
      const perfStart = Date.now();
      const perfRes = http.get(
        `${config.baseUrl}${config.endpoints.analytics.performance}`,
        { headers }
      );
      analyticsDuration.add(Date.now() - perfStart);
      apiCalls.add(1);

      check(perfRes, {
        'performance loaded': (r) => r.status === 200,
        'performance has data': (r) => {
          try {
            const body = JSON.parse(r.body);
            return body.data !== undefined;
          } catch {
            return false;
          }
        }
      }) || errorRate.add(1);

      sleep(2);

      const playersRes = http.get(
        `${config.baseUrl}${config.endpoints.players.list}`,
        { headers }
      );
      apiCalls.add(1);

      if (playersRes.status === 200) {
        try {
          const body = JSON.parse(playersRes.body);
          const players = body.data || body;

          if (Array.isArray(players) && players.length > 0) {
            const randomPlayer = players[Math.floor(Math.random() * players.length)];

            const champRes = http.get(
              `${config.baseUrl}${config.endpoints.analytics.champions(randomPlayer.id)}`,
              { headers }
            );
            apiCalls.add(1);

            check(champRes, {
              'champion stats loaded': (r) => r.status === 200,
            }) || errorRate.add(1);
          }
        } catch (e) {
          console.error('Failed to parse players:', e);
          errorRate.add(1);
        }
      }

      sleep(4);
    });
  }

  // Scenario 3: Player management workflow (10% of users)
  else {
    group('Player Management Workflow', () => {
      const playersRes = http.get(
        `${config.baseUrl}${config.endpoints.players.list}`,
        { headers }
      );
      apiCalls.add(1);

      check(playersRes, {
        'players list loaded': (r) => r.status === 200,
      }) || errorRate.add(1);

      sleep(2);

      const statsRes = http.get(
        `${config.baseUrl}${config.endpoints.players.stats}`,
        { headers }
      );
      apiCalls.add(1);

      check(statsRes, {
        'player stats loaded': (r) => r.status === 200,
      }) || errorRate.add(1);

      sleep(3);
    });
  }

  sleep(Math.random() * 5 + 3);
}

export function teardown(data) {
  console.log('Load test completed');
}
