# Error codes

All API errors follow a consistent JSON structure. HTTP status codes carry standard
semantics; the `code` field provides machine-readable context for the specific
failure.

---

## Error response format

Every error response has this shape:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable description"
  }
}
```

For validation errors the response includes an additional `details` object with
per-field messages:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": {
      "summoner_name": ["can't be blank"],
      "role": ["is not included in the list"]
    }
  }
}
```

For some domain errors, `details` carries structured hints rather than field errors:

```json
{
  "error": {
    "code": "PLAYER_NOT_FOUND",
    "message": "Player not found in Riot API",
    "details": {
      "hint": "Please verify the exact Riot ID in the League client (Settings > Account > Riot ID)"
    }
  }
}
```

---

## HTTP status codes

### 200 OK

The request succeeded. The response body contains a `data` object and an optional
`message` string.

### 201 Created

A new resource was created. Same structure as 200 but indicates creation.

### 400 Bad Request

The request is malformed or missing required parameters.

Common causes:
- Required parameter absent from the body
- Malformed JSON
- `refresh_token` not sent to `/auth/refresh`

### 401 Unauthorized

Authentication failed or the token is no longer valid.

| Code                  | Cause                                                  |
|-----------------------|--------------------------------------------------------|
| `UNAUTHORIZED`        | Missing Authorization header                           |
| `UNAUTHORIZED`        | Token expired (see message: "Token has expired")       |
| `UNAUTHORIZED`        | Token revoked (blacklisted after logout or rotation)   |
| `UNAUTHORIZED`        | User not found (account deleted after token was issued)|
| `INVALID_CREDENTIALS` | Wrong email or password at login                       |
| `INVALID_REFRESH_TOKEN` | Refresh token already used or invalid               |

When you receive 401, check the `message` field:
- "Token has expired" — call `POST /api/v1/auth/refresh`
- "Token has been revoked" — the user must log in again
- "Invalid credentials" — wrong credentials at login

### 403 Forbidden

The token is valid but the authenticated user lacks permission to perform the
requested action. This happens when Pundit denies the action based on the user's
role.

```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "You are not authorized to perform this action",
    "details": {
      "policy": "player_policy",
      "action": "sync_from_riot?"
    }
  }
}
```

Common role requirements:
- `sync_from_riot` — coach or above
- `create` / `update` player — admin or above
- `destroy` player — admin or above
- `bulk_sync` — admin or above

Note: accessing a resource that belongs to another organization returns **404**,
not 403. See [Multi-tenancy](multi-tenancy.md) for the reasoning.

### 404 Not Found

The requested resource does not exist within the authenticated organization's scope.

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Player not found"
  }
}
```

This is also returned when an ID from another organization is used in the URL,
to avoid revealing that the resource exists at all.

### 408 Request Timeout

A database query exceeded the server-side timeout (5 seconds). Retry the request.

```json
{
  "error": {
    "code": "QUERY_TIMEOUT",
    "message": "Request timeout - please try again"
  }
}
```

### 422 Unprocessable Entity

The request is well-formed but validation failed. The `details` object maps field
names to arrays of error messages.

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": {
      "email": ["has already been taken"],
      "password": ["is too short (minimum is 8 characters)"]
    }
  }
}
```

Domain-specific 422 codes:

| Code                    | Meaning                                              |
|-------------------------|------------------------------------------------------|
| `DUPLICATE_EMAIL`       | Email is already registered                          |
| `DUPLICATE_ORGANIZATION`| Organization name already taken                      |
| `DUPLICATE_SUMMONER`    | Summoner name already in platform                    |
| `PLAYER_EXISTS`         | Player already in your organization                  |
| `PASSWORD_MISMATCH`     | `password` and `password_confirmation` do not match  |
| `INVALID_ROLE`          | Role value is not one of: top, jungle, mid, adc, support |

### 429 Too Many Requests

The request was throttled by the rate limiter. The response includes a
`Retry-After` header indicating how many seconds to wait.

```json
{
  "error": {
    "code": "RATE_LIMITED",
    "message": "Too many requests. Please retry later."
  }
}
```

Rate limits:

| Endpoint                        | Limit                |
|---------------------------------|----------------------|
| `POST /api/v1/auth/login`       | 5 per 20 seconds per IP |
| `POST /api/v1/auth/player-login`| 5 per 20 seconds per IP |
| `POST /api/v1/auth/register`    | 10 per hour per IP   |
| `POST /api/v1/auth/player-register` | 5 per hour per IP |
| `POST /api/v1/auth/forgot-password` | 5 per hour per IP |
| All authenticated endpoints     | 1000 per hour per user |
| All endpoints                   | 300 per 5 minutes per IP (global) |

When you receive 429, read the `Retry-After` header and wait that number of
seconds before retrying.

### 500 Internal Server Error

An unexpected error occurred on the server. In production, the message is generic
to avoid leaking implementation details.

```json
{
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "An internal error occurred"
  }
}
```

### 503 Service Unavailable

A downstream dependency (Riot API, background job service) is unavailable.

| Code                           | Meaning                                                  |
|--------------------------------|----------------------------------------------------------|
| `SYNC_ERROR`                   | Riot API returned an error during sync                   |
| `RIOT_API_ERROR`               | Riot API returned an unexpected error during import      |
| `BACKGROUND_SERVICE_UNAVAILABLE` | Redis is down; Sidekiq jobs cannot be enqueued         |
| `RIOT_API_NOT_CONFIGURED`      | `RIOT_API_KEY` is not set on the server                  |

---

## Handling 401 vs 403

These two codes are frequently confused:

- **401 Unauthorized** means the request could not be authenticated. The client
  should obtain a valid token (by refreshing or logging in again) and retry.
- **403 Forbidden** means the request was authenticated but the user's role does
  not permit the action. Retrying with the same token will not help. Elevate the
  user's role or use a different account.

Quick check:

```
401 → token problem → refresh or log in again
403 → permissions problem → contact your organization owner
```

---

## Reporting bugs

If you receive a 500 that appears to be a bug, email
[support@prostaff.gg](mailto:support@prostaff.gg) with:

- The full URL and HTTP method
- The request body (redact passwords and tokens)
- The timestamp of the request
- The full response body

---

## See also

- [Authentication](authentication.md) — token lifecycle and refresh flow
- [Multi-tenancy](multi-tenancy.md) — why cross-org access returns 404
