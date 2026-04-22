# Multi-tenancy

Every resource in ProStaff belongs to an organization. This isolation is enforced at
the application layer on every query, so data from one organization is never visible
to another.

---

## 1. What organization_id is

Every user and player belongs to exactly one organization. When a user logs in, their
JWT encodes the `organization_id`:

```json
{
  "user_id": "a1b2c3d4-...",
  "organization_id": "e5f6g7h8-...",
  "role": "coach",
  "email": "coach@yourteam.gg",
  "type": "access"
}
```

The server extracts `organization_id` from the token on every authenticated request.
There is no URL parameter or request body field for it — clients cannot influence
which organization the request runs against.

---

## 2. Why UUIDs and not sequential IDs

All primary keys are UUIDs (v4). Sequential integer IDs expose two risks:

- **IDOR (Insecure Direct Object Reference):** a client can guess adjacent IDs
  and attempt to access records belonging to other organizations.
- **Enumeration:** the highest ID reveals how many records exist in the system.

UUIDs are randomly generated and statistically unguessable, eliminating both risks.
Even if a client somehow obtained a UUID from another organization, the organization
scope applied on the server would still block access.

---

## 3. How scoping works in the codebase

The `Authenticatable` concern (included in `BaseController`) exposes a helper:

```ruby
def organization_scoped(model_class)
  model_class.where(organization: current_organization)
end
```

Every controller method that reads data uses this helper or the association directly:

```ruby
# Correct — scoped to the authenticated organization
players = organization_scoped(Player).where(status: 'active')
player  = organization_scoped(Player).find(params[:id])

# Also correct — via association
current_organization.players.find(params[:id])
```

Raw unscoped lookups (`Player.find(...)`) are only permitted in background jobs
(Sidekiq), where `Current.organization` is not available and the job validates
ownership manually via a passed `organization_id` argument.

---

## 4. What happens when you access a resource from another organization

The server returns **404 Not Found**, not 403 Forbidden.

This is intentional. A 403 would confirm that the resource exists — leaking
information about another tenant. A 404 reveals nothing.

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Player not found"
  }
}
```

This behavior is automatic: `organization_scoped(Player).find(id)` raises
`ActiveRecord::RecordNotFound` when no row matches the scoped query, regardless
of whether the ID belongs to another organization or does not exist at all.

---

## 5. How organization_id is extracted from the JWT

On every request, `Authenticatable#authenticate_request!` decodes the token and
sets the current organization:

```ruby
# For user tokens
@current_user         = User.unscoped.find(@jwt_payload[:user_id])
@current_organization = @current_user.organization

# For player tokens
@current_player       = Player.unscoped.find(@jwt_payload[:player_id])
org_id                = @jwt_payload[:organization_id]
@current_organization = org_id.present? ? Organization.find(org_id) : nil
```

`Current.organization_id` is set as a thread-local value so it is available
throughout the request lifecycle without passing it explicitly.

---

## 6. Multi-tenant isolation in supporting systems

### Cache

Cache keys are namespaced by organization ID to prevent cross-tenant cache hits:

```
org:<organization_id>:stats
org:<organization_id>:players
```

A cache entry written for organization A can never be read by organization B.

### Redis streams (Action Cable)

The messaging system streams are isolated by organization:

```ruby
stream_from "team_channel_#{current_organization.id}"
```

A WebSocket client connected with organization A's token cannot subscribe to
organization B's stream.

### Meilisearch indexes

Search indexes are scoped per organization using filtered search. Documents
include `organization_id` as an attribute and all search queries include a
filter on the authenticated organization's ID. A full-text search for "Faker"
only returns results belonging to the requesting organization.

---

## See also

- [Authentication](authentication.md) — how the JWT is structured and verified
- [Error codes](error-codes.md) — 404 vs 403 explained in full
