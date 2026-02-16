import http from 'k6/http';

export default function() {
  const payload = JSON.stringify({
    email: 'test@prostaff.gg',
    password: 'TestPassword123'
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  const res = http.post('http://localhost:3333/api/v1/auth/login', payload, params);

  console.log('Status:', res.status);
  console.log('Body:', res.body);

  if (res.status === 200) {
    const body = JSON.parse(res.body);
    console.log('Token:', body.data?.access_token || body.access_token || body.token);
  }
}
