# Domain checklists: backend and data stores

Checks for backend services, data stores and their interfaces. Each line names a failure and how to provoke and observe it.
Use the sections whose "Applies when" line matches the software under test. Turn each relevant line into a QA case and take its expected result from the requirements.

## HTTP and GraphQL APIs

Applies when: the repository has route, controller, handler or resolver modules, an `openapi.yaml`, `swagger.json` or `schema.graphql` file, or a web framework such as Express, NestJS, FastAPI, Django REST Framework, Spring Web, Gin, Rails or Apollo Server.

- A client overwrites server-owned fields → PATCH your own record adding `role`, `owner_id`, `tenant_id` and `price`, then GET it; each must be unchanged and no secret field returned.
- CORS reflects any origin with credentials allowed → send `Origin: https://evil.example`, then `Origin: null`, to an authenticated endpoint with `curl -i`; neither may come back in `Access-Control-Allow-Origin` beside `Access-Control-Allow-Credentials: true`.
- A retried POST duplicates records → send one POST twice with the same `Idempotency-Key`, sequentially then concurrently; exactly one record must exist, with the repeat answered by the original response or 409.
- Concurrent edits silently overwrite each other → GET a resource, then send two different PUT requests carrying the original ETag or version; the second must fail with 412 or 409.
- One request exhausts the server → send `?limit=100000000`, a GraphQL query nested 50 levels deep and one repeating an expensive field under 500 aliases; each must be clamped or rejected promptly.
- A hung dependency stalls every endpoint → freeze a disposable dependency container with `docker pause`, then call dependent and unrelated endpoints; expect 503 or 504 within the timeout and unrelated endpoints unaffected.

## Relational databases and schema migrations

Applies when: the repository has a migrations directory (`migrations/`, `alembic/versions/`, `db/migrate/`, `prisma/migrations/`), Flyway `V*__*.sql` files, Liquibase changelogs, an ORM or migration tool such as SQLAlchemy, Django, Prisma, TypeORM, Knex, Sequelize, ActiveRecord or golang-migrate, or a `DATABASE_URL` setting.

- The new schema breaks the previous release → migrate a disposable database copy, exercise the previous release against it, then run the down migration; look for missing-column errors and lost rows.
- A migration half-applies on real data → seed a disposable database with NULLs, duplicates and over-length values violating the change, then migrate; it must complete or change nothing, version table included.
- Concurrent read-modify-write loses updates → set a stock value to 50, send 50 decrements through `xargs -P 50 curl`, then query the row; it must equal 50 minus the number of successes.
- A failed multi-statement write leaves half-written rows → send a request whose second statement violates a constraint, then query for parent rows that lack their children.
- Uniqueness checked only in code admits duplicates → send 20 concurrent create requests with one email, then run `SELECT email FROM users GROUP BY email HAVING count(*) > 1`; expect no rows.
- Migration DDL blocks the table → in a disposable database hold `BEGIN; SELECT 1 FROM t LIMIT 1;` open, migrate from another session while timing concurrent inserts; none may stall beyond `lock_timeout`.
- Zone-less timestamps are reinterpreted → write one, restart a local instance under `TZ=America/New_York` and read it back unchanged; then store the ambiguous local time 2027-11-07 01:30 and check which instant was kept.

## Authentication, authorisation and tenant isolation

Applies when: the repository has login, session, token or permission code, a dependency such as Passport, NextAuth, Devise, django-allauth, Spring Security, Keycloak, PyJWT, jsonwebtoken or Casbin, `tenant_id` or `org_id` columns, row-level security policies, or settings such as `JWT_SECRET`, `SESSION_SECRET` or `OIDC_ISSUER`.

- A changed object ID reaches another user's data → with user A's token, call every ID-taking route and method using IDs owned by user B in another tenant; expect 403 or 404.
- Collection endpoints leak other tenants' rows → as tenant A, call every list, search, export and count endpoint, then repeat with `?tenant_id=B` and `X-Tenant-ID: B`; none may return or count B's rows.
- Admin endpoints answer non-admin callers → list the admin routes from the router or OpenAPI file, then call each with an ordinary user's token and with none; expect 403 and 401 respectively.
- Forged or expired tokens are accepted → send four JWTs: `alg` set to `none`, payload edited without re-signing, validly signed but expired, and issued for another service's `aud`; expect 401 each time.
- Tenant context leaks between concurrent requests → run two scripted clients for different tenants in parallel for 60 seconds against the same endpoints; every response must carry only the caller's tenant ID.
- Tokens survive logout and privilege changes → capture access and refresh tokens, then log out, change the password, remove a role and deactivate the user; after each step, replaying either must fail.
- Login and one-time-code endpoints allow unlimited guesses → send 100 wrong passwords or codes for one test account while rotating `X-Forwarded-For`; expect 429 or a lockout well before the hundredth attempt.

## Payments, billing and money arithmetic

Applies when: the repository uses a payment SDK such as Stripe, Braintree, Adyen, PayPal, Paddle or Toss Payments, exposes a webhook route such as `/webhooks/stripe`, defines invoice, subscription, refund or ledger models, or handles `amount` and `currency` fields with a money or decimal library.

- A retry or double click charges twice → submit one checkout twice concurrently and once more after a forced timeout, reusing the order ID; the provider's sandbox must list exactly one charge.
- The server trusts client-supplied amounts → send checkout requests carrying a lower `amount`, `quantity: -1`, a cheaper price ID or another currency; each must fail or charge the catalogue total.
- The webhook accepts forged or replayed events → POST a `payment_intent.succeeded` event unsigned, wrongly signed, and validly signed with a timestamp older than the tolerance; each must be rejected and change nothing.
- Fulfilment follows the browser redirect → open the success URL for a session declined with test card 4000000000000002, then pay successfully without loading that page; entitlement must match payment status both times.
- Duplicate or out-of-order webhooks corrupt state → deliver one event twice with `stripe events resend <id>` and replay a subscription's events in reverse order; credit must apply once and status never regress.
- Minor-unit conversion is wrong → check out a 1000 JPY item and a 19.99 USD item; the provider must receive `amount=1000` and `amount=1999`, not 100000 or 1998. Repeat with three-decimal KWD.
- Racing refunds or redemptions exceed their limit → fire ten concurrent redemptions of one single-use coupon, then two concurrent partial refunds together exceeding the charge; only one of each may succeed.

## Workers, queues and schedulers

Applies when: the repository depends on Celery, RQ, Dramatiq, Sidekiq, BullMQ, Temporal or a Kafka, RabbitMQ, SQS or NATS client, or has worker entrypoints, `jobs/`, `tasks/` or `consumers/` directories, a Procfile `worker:` line, crontab entries, Kubernetes CronJob manifests or a beat schedule.

- Redelivery repeats a side effect → publish the same message twice with one message ID, then count the resulting emails, rows or outbound calls; exactly one side effect may exist.
- A killed worker loses its job → start a 30-second job, run `kill -9` on the local worker executing it, restart the worker and confirm the job runs again to completion.
- Commit and enqueue are not atomic → stop a disposable broker, call a write endpoint that enqueues a job, then restart the broker; both row and job must exist, or neither.
- Queued jobs vanish on broker restart or eviction → enqueue 1000 delayed jobs on a disposable broker, restart it and count them again; for Redis, `redis-cli CONFIG GET maxmemory-policy` must return `noeviction`.
- One malformed message blocks the queue → publish invalid JSON, then a payload missing a required field, then a valid message; expect bounded retries, dead-letter entries, and the valid message processed.
- Every replica fires each cron job → start two instances of the application or scheduler, wait for one scheduled tick, then count executions in the logs or database; exactly one may occur.

## Caching layers

Applies when: the repository depends on Redis, Memcached or an in-process cache such as lru-cache, Caffeine or `functools.lru_cache`, uses `@Cacheable` or a framework `CACHES` setting, sets `Cache-Control` headers, or configures a CDN or reverse-proxy cache such as Varnish, nginx `proxy_cache`, CloudFront or Cloudflare.

- One user's cached response reaches another → request one URL as user A, then as user B and anonymously; compare bodies, `Cache-Control`, `Vary`, `Age` and `X-Cache`; neither may receive A's data.
- An unkeyed header poisons the cache → send `X-Forwarded-Host: evil.example` on a cacheable URL with a unique query string, then repeat without the header; the second response must not contain `evil.example`.
- A write leaves lists and counts stale → warm the item, list and count endpoints, update the item, then immediately re-read all three through every instance; each must show the new value.
- A racing reader re-caches the old value → run concurrent writers and readers on one key for 30 seconds, then wait two seconds; the cached value must equal the database row.
- A cache outage takes the application down → run `docker stop`, then `docker pause`, on a disposable cache container while calling cached endpoints; expect correct responses within the timeout and clean recovery.
- Hot-key expiry stampedes the database → in a disposable stack, delete a hot key with `redis-cli DEL`, send 200 concurrent requests for it and count logged database queries; expect about one recomputation.

## WebSockets and server-sent events

Applies when: the repository depends on `ws`, Socket.IO, SockJS, Django Channels, ActionCable, SignalR, Phoenix Channels, gorilla/websocket or graphql-ws, serves `text/event-stream` responses, uses `EventSource` or `new WebSocket` in client code, or sets proxy `Upgrade` and `Connection` headers.

- Naming another user's channel subscribes to it → with user A's token, open a `websocat` socket and subscribe to user B's channel or room; expect a refusal and none of B's events.
- The handshake skips origin or credential checks → connect with `websocat --origin https://evil.example` plus a valid session cookie, and again with no credentials; both handshakes must be refused.
- Sockets outlive logout or token expiry → open an authenticated socket, log out or revoke the token, then wait past its expiry; the server must close the socket and send nothing more.
- One bad frame disconnects everyone → with another client connected, send invalid JSON, a binary frame and a 50-megabyte frame; expect error replies or close code 1009, and the other client undisturbed.
- Reconnection loses or repeats events → note the last event ID, drop the connection, emit five events and reconnect sending `Last-Event-ID` or the resume offset; those five must arrive once, in order.
- Events miss clients on other instances → start two server instances, connect one client directly to each, trigger an event through the first, and confirm both clients receive it exactly once.

## Search and indexing

Applies when: the repository uses a client for Elasticsearch, OpenSearch, Solr, Meilisearch, Typesense or Algolia, PostgreSQL full-text features such as `tsvector`, `to_tsquery`, GIN indexes or `pg_trgm`, SQLite FTS5 or a vector store such as pgvector, or contains index mappings, analyser settings or reindex scripts.

- Search reveals private documents → as user A, index a private document containing `zqxj7731`; as user B and anonymously, query search, suggest and facet endpoints for it; expect zero hits and counts.
- Deleted or revoked documents stay searchable → index a document with a unique token, find it, then delete, unpublish or revoke it; hits must reach zero within the stated freshness window.
- Raw input reaches the query parser → search for `"`, `(`, `AND`, `secret_field:*`, `*a*`, `/.*.*.*/` and a 10000-character string; each must return 200 or 400 quickly, never 500 or another field's data.
- Writes during an outage stay unindexed → stop a disposable search engine, create, update and delete records, restart it, then compare the database count with `GET /<index>/_count` and search for each change.
- Bulk indexing drops failed documents silently → bulk-index a batch where one document has text in a date field; the indexer must log or retry that item, and counts must reconcile.
- A reindex loses writes made mid-rebuild → start a full reindex and, while it runs, create, update and delete one document each; after the switch, search must reflect all three changes.
