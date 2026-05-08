# Authentication

ProStaff uses JWT (JSON Web Token) for authentication. Every request to a protected
endpoint must include a valid access token in the `Authorization` header.

There are two distinct auth paths: **user auth** (for staff members — owner, admin,
coach, analyst) and **player auth** (for individual player access). They use separate
login endpoints and produce tokens with different payloads and permission scopes.

---

## 1. Login and obtain tokens

### User login

```
POST /api/v1/auth/login
```

Request body:

```json
{
  "email": "coach@yourteam.gg",
  "password": "yourpassword"
}
```

Successful response (200):

```json
{
  "message": "Login successful",
  "data": {
    "user": {
      "id": "a1b2c3d4-...",
      "email": "coach@yourteam.gg",
      "full_name": "Jane Coach",
      "role": "coach"
    },
    "organization": {
      "id": "e5f6g7h8-...",
      "name": "Team Valor"
    },
    "access_token": "eyJhbGciOiJIUzI1NiJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiJ9...",
    "expires_in": 86400,
    "token_type": "Bearer"
  }
}
```

### Player login

Players authenticate with a separate endpoint using a `player_email` field
(distinct from the staff `email` field):

```
POST /api/v1/auth/player-login
```

Request body:

```json
{
  "player_email": "player@example.com",
  "password": "playerpassword"
}
```

Successful response (200):

```json
{
  "message": "Login realizado com sucesso",
  "data": {
    "player": {
      "id": "p1q2r3s4-...",
      "summoner_name": "Faker#KR1",
      "role": "mid",
      "organization_id": "e5f6g7h8-..."
    },
    "access_token": "eyJhbGciOiJIUzI1NiJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiJ9...",
    "expires_in": 86400,
    "token_type": "Bearer"
  }
}
```

Player access must be explicitly enabled by staff before a player can log in.
Attempting to log in with a disabled account returns 401 `INVALID_CREDENTIALS`.

---

## 2. Using the Authorization header

Include the access token in every request to a protected endpoint:

```
Authorization: Bearer <access_token>
```

The header value must start with `Bearer ` (case-insensitive) followed by the token.
Requests without this header, or with a malformed header, receive:

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing authentication token"
  }
}
```

---

## 3. Token lifetime

| Token         | Lifetime        | Configurable via ENV              |
|---------------|-----------------|-----------------------------------|
| access_token  | 24 hours        | `JWT_EXPIRATION_HOURS` (default 24) |
| refresh_token | 7 days          | `JWT_REFRESH_EXPIRATION_DAYS` (default 7) |

---

## 4. Refreshing the access token

When the access token expires, use the refresh token to obtain a new pair without
requiring the user to log in again. Refresh tokens are single-use: each call to
this endpoint invalidates the submitted refresh token and returns a fresh pair.

```
POST /api/v1/auth/refresh
```

Request body:

```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

Successful response (200):

```json
{
  "message": "Token refreshed successfully",
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiJ9...",
    "expires_in": 86400,
    "token_type": "Bearer"
  }
}
```

If the refresh token has already been used or is invalid, the response is 401:

```json
{
  "error": {
    "code": "INVALID_REFRESH_TOKEN",
    "message": "Refresh token already used"
  }
}
```

---

## 5. Logout

Logout blacklists the current access token in Redis so it cannot be reused before
its natural expiry. Send the refresh token in the body to also invalidate it — this
is strongly recommended to prevent session reuse after logout.

```
POST /api/v1/auth/logout
```

Request body (optional but recommended):

```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

Successful response (200):

```json
{
  "message": "Logout successful",
  "data": {}
}
```

Omitting the refresh token is not an error, but the refresh token will remain valid
until its natural expiry. An attacker who obtained it could create new sessions.

---

## 6. What happens when a token expires

A request with an expired access token receives 401:

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Token has expired"
  }
}
```

When you receive this response, call `POST /api/v1/auth/refresh` with your stored
refresh token. If the refresh token has also expired or been revoked, the user must
log in again with their credentials.

---

## 7. User auth vs Player auth

| Aspect              | User token                                | Player token                                |
|---------------------|-------------------------------------------|---------------------------------------------|
| Login endpoint      | `POST /api/v1/auth/login`                 | `POST /api/v1/auth/player-login`            |
| Credential field    | `email`                                   | `player_email`                              |
| Token payload       | `user_id`, `organization_id`, `role`      | `entity_type: "player"`, `player_id`, `organization_id` |
| Roles available     | owner, admin, coach, analyst              | player (limited scope)                      |
| Pundit enforcement  | Full policy evaluation                    | Restricted to player-specific endpoints     |
| Staff endpoints     | Accessible (role-dependent)               | Blocked (`require_user_auth!` guard)         |

Refresh and logout endpoints work the same way for both token types.

---

## 8. Complete cURL flow: login, request, refresh

```bash
# Step 1 — login and capture tokens
RESPONSE=$(curl -s -X POST https://api.prostaff.gg/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"coach@yourteam.gg","password":"yourpassword"}')

ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.data.access_token')
REFRESH_TOKEN=$(echo "$RESPONSE" | jq -r '.data.refresh_token')

# Step 2 — authenticated request
curl -s https://api.prostaff.gg/api/v1/players \
  -H "Authorization: Bearer $ACCESS_TOKEN"

# Step 3 — refresh when token expires (201 Unauthorized triggers this)
NEW_TOKENS=$(curl -s -X POST https://api.prostaff.gg/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d "{\"refresh_token\":\"$REFRESH_TOKEN\"}")

ACCESS_TOKEN=$(echo "$NEW_TOKENS" | jq -r '.data.access_token')
REFRESH_TOKEN=$(echo "$NEW_TOKENS" | jq -r '.data.refresh_token')

# Step 4 — logout
curl -s -X POST https://api.prostaff.gg/api/v1/auth/logout \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"refresh_token\":\"$REFRESH_TOKEN\"}"
```

---

## See also

- [Multi-tenancy](multi-tenancy.md) — how organization_id is enforced on every request
- [Error codes](error-codes.md) — full list of error responses
- [Quick start](quickstart.md) — end-to-end walkthrough from registration to first request
