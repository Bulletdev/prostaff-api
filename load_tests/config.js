// k6 Load Test Configuration
// Centralized configuration for all load tests

export const config = {
  // Base URL - change based on environment
  baseUrl: __ENV.BASE_URL || 'http://localhost:3333',

  // Test credentials
  testUser: {
    email: __ENV.TEST_EMAIL || 'test@prostaff.gg',
    password: __ENV.TEST_PASSWORD || 'Test123!@#'
  },

  // Load test profiles
  profiles: {
    // Smoke test - minimal load
    smoke: {
      stages: [
        { duration: '1m', target: 1 },
      ],
      thresholds: {
        http_req_duration: ['p(95)<500'],
        http_req_failed: ['rate<0.01'],
      }
    },

    // Load test - normal traffic
    load: {
      stages: [
        { duration: '2m', target: 10 },   // Ramp-up
        { duration: '5m', target: 10 },   // Stay at 10 users
        { duration: '2m', target: 50 },   // Ramp to 50 users
        { duration: '5m', target: 50 },   // Stay at 50 users
        { duration: '2m', target: 0 },    // Ramp-down
      ],
      thresholds: {
        http_req_duration: ['p(95)<1000', 'p(99)<2000'],
        http_req_failed: ['rate<0.05'],
      }
    },

    // Stress test - push to limits
    stress: {
      stages: [
        { duration: '2m', target: 50 },   // Warm up
        { duration: '5m', target: 50 },
        { duration: '2m', target: 100 },  // Increase load
        { duration: '5m', target: 100 },
        { duration: '2m', target: 200 },  // Push harder
        { duration: '5m', target: 200 },
        { duration: '2m', target: 300 },  // Break point
        { duration: '5m', target: 300 },
        { duration: '5m', target: 0 },    // Recovery
      ],
      thresholds: {
        http_req_duration: ['p(95)<2000'],
        http_req_failed: ['rate<0.1'],
      }
    },

    // Spike test - sudden traffic surge
    spike: {
      stages: [
        { duration: '1m', target: 10 },   // Normal load
        { duration: '30s', target: 500 }, // Spike!
        { duration: '3m', target: 500 },  // Sustain spike
        { duration: '1m', target: 10 },   // Back to normal
        { duration: '2m', target: 0 },    // Cool down
      ],
      thresholds: {
        http_req_duration: ['p(95)<3000'],
        http_req_failed: ['rate<0.15'],
      }
    },

    // Soak test - sustained load over time
    soak: {
      stages: [
        { duration: '5m', target: 50 },    // Ramp up
        { duration: '3h', target: 50 },    // Sustained load
        { duration: '5m', target: 0 },     // Ramp down
      ],
      thresholds: {
        http_req_duration: ['p(95)<1000'],
        http_req_failed: ['rate<0.05'],
      }
    }
  },

  // API endpoints to test
  endpoints: {
    auth: {
      login: '/api/v1/auth/login',
      register: '/api/v1/auth/register',
      me: '/api/v1/auth/me',
      refresh: '/api/v1/auth/refresh',
    },
    dashboard: {
      index: '/api/v1/dashboard',
      stats: '/api/v1/dashboard/stats',
      activities: '/api/v1/dashboard/activities',
      schedule: '/api/v1/dashboard/schedule',
    },
    players: {
      list: '/api/v1/players',
      show: (id) => `/api/v1/players/${id}`,
      stats: '/api/v1/players/stats',
    },
    analytics: {
      performance: '/api/v1/analytics/performance',
      champions: (playerId) => `/api/v1/analytics/champions/${playerId}`,
      kdaTrend: (playerId) => `/api/v1/analytics/kda-trend/${playerId}`,
    },
    matches: {
      list: '/api/v1/matches',
      show: (id) => `/api/v1/matches/${id}`,
    }
  }
};

// Helper function to get auth token
export function getAuthToken(http) {
  const loginRes = http.post(
    `${config.baseUrl}${config.endpoints.auth.login}`,
    JSON.stringify({
      email: config.testUser.email,
      password: config.testUser.password
    }),
    {
      headers: { 'Content-Type': 'application/json' },
    }
  );

  if (loginRes.status === 200) {
    const body = JSON.parse(loginRes.body);
    return body.data?.access_token || body.access_token || body.token;
  }

  console.error('Failed to authenticate:', loginRes.status, loginRes.body);
  return null;
}

// Helper function to create auth headers
export function authHeaders(token) {
  return {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  };
}
