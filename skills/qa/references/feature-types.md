# Feature-type checklists

Checks for kinds of feature that recur across domains. Each line names a failure and how to provoke and observe it.
Use the sections whose "Applies when" line matches the software under test. Turn each relevant line into a QA case and take its expected result from the requirements.

## CRUD on records

Applies when: the repository has route, controller or resolver files (`routes/`, `controllers/`, `views.py`) exposing POST, GET, PUT, PATCH and DELETE for one resource, ORM models with migrations, or OpenAPI paths such as `/items` and `/items/{id}`.

- Another user's record is reachable by ID → as test user B, send GET, PUT, PATCH and DELETE to test user A's record ID; expect 403 or 404 and unchanged data.
- The client sets fields it must not control → add `owner_id`, `role`, `is_admin` or `price` to a create or update body, then read the record back; expect them ignored or rejected.
- A concurrent edit is silently overwritten → read a record twice, then send two different updates carrying the same stale version or ETag; expect the second refused with 409 or 412.
- Delete orphans children and files or cascades too far → delete a seeded parent that has children, attachments and inbound references; query each and compare with the stated delete rule.
- The update path skips validation that create enforces → update a valid record to values create rejects: empty required field, duplicate unique value, over-long text, invalid reference; expect the same errors.
- A partial update resets omitted fields → PATCH one field and diff the full record before and after; repeat with another field set to null and expect only that field cleared.

## Lists: search, filter, sort, pagination

Applies when: the repository has list endpoints or pages taking `page`, `limit`, `offset`, `cursor`, `sort`, `order`, `q`, `search` or `filter` parameters, a pagination or filter library (django-filter, Spring Data Pageable, kaminari, TanStack Table), or a search index such as Elasticsearch, OpenSearch or Meilisearch.

- The list, search or total leaks other users' records → as user B, list and search with filters matching only user A's records; expect zero items, zero total and no facet counts.
- The sort parameter reaches SQL or orders numbers as text → send `sort=unknown` and `sort=id;select 1` and expect 400; then sort 9, 10, 100 and null and expect numeric order.
- A huge or negative page size dumps the whole table → request `limit=1000000`, `limit=-1`, `limit=0` and `page=999999999`; expect a capped page or 400, with bounded response time and size.
- A sort key without a unique tiebreaker repeats or drops rows → seed 50 rows sharing one sort value, walk every page of size 10, and expect 50 distinct IDs.
- Filtering runs after pagination and returns short pages → seed matches only beyond the first unfiltered page; expect a full filtered first page and a total equal to the match count.
- Search treats `%`, `_` or a quote as a wildcard or SQL → search for `%`, `_`, `100%`, `a_b`, a single quote and a backslash; expect only literal matches, never a 500.

## File upload and download

Applies when: the repository has multipart handlers or upload middleware (multer, busboy, python-multipart, `MultipartFile`, Active Storage), object storage or presigned URL code (boto3, MinIO, S3, GCS), size settings such as `client_max_body_size` or `MAX_UPLOAD_SIZE`, or download routes that set `Content-Disposition`.

- A crafted filename writes outside the upload directory → upload with `curl -F 'file=@a.txt;filename=../../tmp/qa-probe.txt'` and with an absolute path; expect nothing outside storage and a sanitised stored name.
- Another user or anonymous client downloads a private file → fetch user A's file URL as user B, without credentials, and after the signed URL expires; expect 403 or 404 each time.
- An uploaded SVG or HTML file runs script → upload an SVG with a script tag as `image/png`, then `curl -I` its URL; expect `Content-Disposition: attachment` or a safe type, plus `nosniff`.
- The type check trusts the extension or Content-Type header → upload a shell script named `photo.jpg`, a file named `a.jpg.php` and a PNG sent as `text/html`; expect each rejected or stored inert.
- Uploads sharing a filename overwrite each other or cross users → have two users upload different content as `report.pdf` at the same moment; download both and compare each SHA-256 with its source.
- The size limit applies only after buffering the body → stream a body ten times the limit with `Transfer-Encoding: chunked` and no `Content-Length`; expect an early 413 and flat server memory.

## Data import and export

Applies when: the repository uses CSV, spreadsheet or archive libraries (csv, pandas, openpyxl, SheetJS, PapaParse, Apache POI), has endpoints or commands named import, export, bulk or download, returns `text/csv` or spreadsheet content types, or ships sample or template data files.

- Exported cells execute as formulas in a spreadsheet → store `=HYPERLINK("http://x","y")`, `+1`, `-1` and `@SUM(1)` in text fields, export, and inspect the raw file; expect each cell neutralised.
- The export exceeds the user's access or ignores the filter → as a restricted user, export with a filter applied; compare row IDs and column names with that user's list API response.
- The importer bypasses validation, permissions or audit → import a row the create API rejects (bad email, duplicate key, missing parent); expect the same rejection, and an audit entry per imported row.
- A failure at row N leaves an unreported partial import → import 100 rows with row 57 invalid; expect zero rows stored or a report naming row 57, with matching database counts.
- A large export truncates yet reports success → seed a test database with more rows than any cap (for example 100,001), export, and compare line count and last line with the database.
- An export-import round trip alters values → seed `00123`, a 19-digit ID, an empty string, null, and text with comma, quote and newline; export, import into a clean instance, re-export and diff.

## Sign-up, login, password reset, sessions

Applies when: the repository uses authentication libraries (passport, next-auth, devise, django.contrib.auth, Spring Security, bcrypt, argon2, jsonwebtoken), has routes named login, signup, register, logout, reset or verify, session or cookie configuration, or settings such as `JWT_SECRET`, `SESSION_SECRET` or token lifetimes.

- A reset token works twice or after its expiry → complete a reset, submit the same link again, and submit another link after it expires; expect both refused and the password unchanged.
- The reset link is built from the request Host header → request a reset with `Host: evil.example` and with `X-Forwarded-Host: evil.example`; read the test mailbox and check the link's domain.
- Old sessions and tokens survive logout or password change → save the session cookie or access and refresh tokens, log out or change the password, then replay them with curl; expect 401.
- Guesses are unlimited, or lockout blocks the victim → send 200 wrong passwords or codes for one test account in a loop; expect throttling, then check whether the correct password still works.
- Email variants create a second account or hijack one → with `user@example.com` registered, sign up and request resets as `User@Example.com`, with a trailing space and with full-width letters; expect one account throughout.
- The session ID stays the same across login → record the `Set-Cookie` value before and after login; expect a new session ID with `Secure`, `HttpOnly` and `SameSite` attributes.
- An unverified account can already sign in and act → sign up, skip the verification link, then log in and call an authenticated endpoint; compare with the stated verification rule.

## Scheduling, recurrence, dates, durations

Applies when: the repository has cron expressions, RRULE strings or interval settings, a scheduler library (node-cron, APScheduler, Quartz, celery beat, Kubernetes CronJob manifests), a date library (moment, date-fns, luxon, pytz, zoneinfo, java.time), or fields named `start_at`, `due_date`, `timezone`, `duration` or `repeat`.

- After downtime, missed runs all fire at once or vanish → stop a local scheduler across three due times of a job, restart it, and count executions against the documented catch-up policy.
- A run that outlasts its interval overlaps the next → make one run last three intervals with a slow dependency or large input; count simultaneous executions and duplicated output rows.
- Schedules run in the server's time zone, not the user's → run the server with `TZ=UTC`, schedule 09:00 daily as an Asia/Seoul user, and record the fire time; expect 00:00 UTC.
- A recurring local time shifts an hour after a clock change → create a daily 09:00 series in America/New_York spanning 2027-03-14 and list occurrences; expect 09:00 local time for each.
- A date without a time moves a day in another time zone → save 2027-03-01 with the client in Asia/Seoul, then read it from clients in UTC and America/Los_Angeles; expect 2027-03-01 everywhere.
- Monthly recurrence from the 31st skips short months or drifts → create a monthly series starting 2027-01-31 and list twelve occurrences; compare February and later months with the stated month-end rule.

## Notifications, alerts, deduplication, throttling

Applies when: the repository has mail, SMS, push or chat clients (nodemailer, smtplib, Twilio, FCM, APNs, Slack webhooks), alert rule or routing files such as `alertmanager.yml`, or code or settings named notify, alert, dedup, fingerprint, cooldown, throttle, digest, `repeat_interval` or `quiet_hours`.

- A coarse deduplication key swallows a second, different incident → within the cooldown, trigger two alerts that differ only in source, such as two hosts; expect two notifications or one naming both.
- Throttling drops the last state change → trigger an alert, then resolve it inside the same throttle window; expect a resolved notification once the window ends.
- One invalid recipient aborts delivery to everyone after it → notify five test recipients where the third has an invalid address or token; expect the other four delivered and the failure recorded.
- Mute, unsubscribe or quiet hours are ignored on some channel → mute or unsubscribe a test recipient, trigger the alert, and check every channel (email, push, SMS, chat, webhook); expect no delivery.
- A flapping condition or changing key value causes a storm → toggle one condition every two seconds for a minute with a varying measurement in the payload; expect a bounded notification count.
- A restart or second replica re-sends delivered notifications → with three alerts active and already notified, restart the local service, then run two replicas; expect no repeat before the repeat interval.

## Settings and configuration

Applies when: the repository has configuration files and loaders (`.env`, `config/*.yaml`, `settings.py`, `application.properties`, `appsettings.json`, dotenv, viper, pydantic-settings), a settings or admin screen with its API, a settings table or key-value store, or code that reads environment variables or reloads configuration.

- A secret leaks, or its masked placeholder overwrites it → grep a test instance's settings response and logs for the secret; PUT that response back unchanged and confirm the integration still authenticates.
- Invalid saved values crash the next start → save a zero interval, a negative number and a malformed URL, then restart the test instance; expect rejection at save and a clean start.
- An upgrade resets or rejects existing settings → start the new build on a copy of the previous release's config file and settings rows; diff the effective configuration before and after.
- Running replicas ignore a saved setting → on a test stack, change a setting through the API and exercise it on every replica and worker without restarting; expect the new value everywhere.
- A falsy string enables a feature → set a boolean to `false`, `0`, `no`, `off` and an empty string through environment and YAML in turn; expect the feature disabled or an error.
- A value is read in another unit than stated → set a test instance's timeout or interval to 5, slow the dependency, and measure the real timeout or period with timestamps.

## Rate limiting and quotas

Applies when: the repository has rate limit middleware or gateway rules (express-rate-limit, slowapi, django-ratelimit, bucket4j, nginx `limit_req`, Envoy or Kong policies), Redis counters, 429 responses with `Retry-After` or `RateLimit` headers, or plan and quota fields such as `max_requests`, `usage` or `limit`.

- The limit is keyed on a client-supplied header → exceed the limit, then repeat with a different random `X-Forwarded-For` value on each request; expect 429 to continue.
- An equivalent path or bulk endpoint is unlimited → after a 429, retry with a trailing slash, changed path case, an older version prefix and the bulk endpoint; expect 429 each time.
- A parallel burst overshoots the quota → with 10 units of quota left, fire 50 requests at once (`xargs -P 50` or `hey`); expect exactly 10 successes.
- Per-instance counters multiply or reset the limit → send four times the limit across three local replicas in one window, restart them and retry; expect at most the limit accepted, then 429.
- One user's traffic exhausts a shared bucket → exhaust the limit as user A, then send one request as user B from the same IP address; expect user B to succeed.
- A counter store outage blocks everyone or stops limiting → stop the test stack's limiter backend, send requests and compare with the documented fail-open or fail-closed rule; expect a logged error.

## Multi-step workflows and state machines

Applies when: the repository has a status or state column with enumerated states, transition tables or a state machine library (xstate, django-fsm, aasm, Spring Statemachine, Temporal, Camunda, AWS Step Functions), endpoints named submit, approve, reject, cancel or confirm, or wizard or checkout step components.

- A later step skips payment, approval or validation → create an item and call the final endpoint (confirm, ship, publish) without the earlier steps; expect 409 or 403 and no state change.
- The final request replaces a value approved earlier → pass validation with a valid amount, then change the amount, price ID or quantity in the final submit; expect rejection or recomputation.
- A duplicate transition repeats its side effect → send one test approve, pay or refund request ten times in parallel; expect one success, the rest 409, and one side effect recorded.
- The requester or an unauthorised role performs a transition → call the approve endpoint as the requester and as a read-only role, directly through the API; expect 403 and an unchanged state.
- A failed or cancelled workflow keeps charges or reservations → make step three fail after step two reserved or charged something, and separately cancel midway; expect the reservation, charge or points reversed.
- A forbidden state transition is accepted → script every transition from every state on seeded items and compare the accepted ones with the specified transition table; expect disallowed pairs refused.

## Numeric calculation, rounding, unit conversion

Applies when: the repository has money, price, tax, quantity, percentage or measurement fields, a decimal or money library (decimal, BigDecimal, decimal.js, dinero.js, money gems), calls to `round`, `toFixed`, `floor` or `ceil`, float columns that hold amounts, or unit or currency conversion tables or constants.

- Zero- and three-decimal currencies are handled as two-decimal → create amounts in JPY or KRW (no decimals) and KWD (three decimals); check the stored minor units, the display and the payment payload.
- A unit conversion is wrong or doubled → enter one known value per unit (1 lb, 1 mile, 100 °F), read it back in every other unit and compare with reference values.
- Binary floating point drifts money by a cent → create lines of 0.10 plus 0.20, 100 units at 19.99 and 3 units at 1.10; expect exactly 0.30, 1999.00 and 3.30.
- Rounded parts do not add up to the total → split 100.00 into three equal shares and spread a percentage discount across three lines; expect parts summing exactly to the total.
- Refunds round differently from the original charge → in a sandbox, charge an amount whose tax rounds at a tie, then refund it in two parts; expect a net of exactly zero.
- Integers beyond int32 or 2^53 overflow or lose digits → store 2147483648 and 9007199254740993 as an ID, quantity or amount; read them back through the API and the interface; expect identical digits.
- A zero denominator yields NaN, Infinity or a 500 → request a rate, average or percentage with zero quantity, zero total and no rows; inspect the JSON for NaN, Infinity or null.

## Text input, parsing, Unicode

Applies when: the repository has free-text fields such as names, comments or search boxes, hand-written parsers, regular expressions or tokenisers, length or character-set limits (`varchar(n)`, `maxLength`, utf8 versus utf8mb4), slug or normalisation helpers, or code that parses text from files, users or language models.

- Stored text is interpreted as markup, template or command → save `<img src=x onerror=alert(1)>`, `{{7*7}}`, `${7*7}`, `$(id)` and a value with CRLF; expect literal text in every screen, email, export and log.
- A validation regex backtracks catastrophically → in a test instance, submit 50,000 repetitions of `a` followed by `!` to each pattern-validated field (email, URL, slug); expect the normal response time.
- A NUL character or lone surrogate breaks storage → send JSON strings containing `\u0000` and the unpaired surrogate `\ud800`; expect a 400 or clean storage, never a 500 or a shortened value.
- Four-byte characters are truncated or replaced by question marks → save a string containing U+1F600 (emoji) and U+20BB7 (rare CJK) in every text field; read it back and expect identical text.
- Invisible or look-alike characters spoof names → submit names made only of U+200B, padded with U+00A0, containing U+202E, and `admin` with Cyrillic U+0430; expect each rejected, trimmed or reported as a duplicate.
- Imperfect model output breaks its parser → stub the model endpoint to return truncated JSON, JSON inside a Markdown code fence, and JSON followed by prose; expect handled errors or correct extraction.

## Reports, aggregates, dashboards

Applies when: the repository has SQL or ORM code with GROUP BY, SUM, COUNT or window functions, materialised views or rollup tables, chart or dashboard components (Chart.js, Recharts, ECharts, Grafana dashboard JSON), report or statistics endpoints, or scheduled jobs that refresh aggregates.

- Aggregates include other tenants' or hidden rows → seed known data for tenants A and B, request every total as a tenant A user, and compare with totals computed from A's rows.
- A one-to-many join inflates sums and counts → seed one order with three items and two payments, request order count and revenue; expect one order and one order total.
- Cancelled, refunded, soft-deleted or test records are still counted → create a record, note the totals, then cancel, refund or delete it; expect the totals to change as the metric's definition states.
- Distinct counts or averages are summed across buckets → seed one user active on three days; expect weekly unique users of 1 and a weekly average equal to total divided by count.
- Pre-aggregated numbers ignore corrections and late records → insert a record dated three days ago, edit one and delete one; after the documented refresh delay expect historical buckets to reflect all three.
- Day buckets use UTC, not the report time zone → insert events at 23:59:59 and 00:00:00 in the report time zone and request daily buckets; expect each event in its local day.

## Webhooks and third-party integrations

Applies when: the repository has routes named webhook, callback or hooks, signature verification code or settings such as `WEBHOOK_SECRET` or `X-Hub-Signature-256`, vendor SDKs or HTTP clients with API keys and base URLs in configuration, OAuth client credentials, or tables that store webhook endpoints or deliveries.

- A forged, unsigned or replayed webhook is accepted → POST an event unsigned and wrongly signed, then replay a captured valid delivery ten minutes later; expect no side effect from any.
- A user-configured webhook URL makes the server call internal addresses → register `http://169.254.169.254/`, `http://127.0.0.1:6379/` and a public URL that redirects to them; expect registration or delivery refused.
- A redelivered event is processed twice → POST the identical signed event, same event ID, twice in sequence and five times in parallel; expect a single side effect.
- A hung third party ties up every worker → point a test instance's integration URL at a silent listener (`nc -l 9999`); expect a timeout error and other endpoints still responding.
- The handler answers 2xx although processing failed → stop the test stack's database or queue and deliver a valid event; expect a non-2xx response or a durable record processed after recovery.
- Out-of-order events leave an older state → deliver the updated or deleted event before the created event, and an older update after a newer one; expect the newest state to win.

## Background jobs, retries, idempotency

Applies when: the repository depends on a queue or worker system (Celery, RQ, Sidekiq, BullMQ, Hangfire, SQS, RabbitMQ, Kafka consumers, Temporal), has a workers or jobs directory with a separate worker process in the Procfile or compose file, or settings such as `max_retries`, `backoff`, `visibility_timeout`, `acks_late` or a dead-letter queue.

- A redelivered job repeats its side effect → `kill -9` a local worker after the job's charge, email or write but before acknowledgement, restart it and count the side effects; expect one.
- A stop signal loses the running job → send SIGTERM to a local worker mid-job; expect the job finished or re-queued, with no row left in running state.
- A job outlasting the visibility timeout is started again → run two workers and make one job outlast the visibility timeout or lock lifetime with a slow input; expect a single execution.
- A permanently failing job retries forever or vanishes → enqueue a test job whose payload always raises and record each retry time; expect bounded retries, then a visible failed or dead-letter record.
- Previous-release job payloads fail under new code → stop the test workers, enqueue jobs with the previous release, start workers from the new build; expect every queued job to complete.
- A job is enqueued before commit → create 200 test records rapidly and grep worker logs for not-found errors; then send a create that fails late and expect no job to run.

## Undo, versioning, audit history

Applies when: the repository has tables or models named versions, revisions, history, `audit_log` or events, soft-delete columns such as `deleted_at`, an auditing library (paper_trail, django-simple-history, Hibernate Envers, audited), or endpoints or commands named undo, restore, revert, rollback or history.

- Undo discards newer edits by other users → have user A edit field X, then user B edit field Y, then user A undo; expect field Y kept or an explicit conflict.
- Erased personal data survives in history or exports → erase a seeded record holding a unique marker string, then search its history, audit and export endpoints for the marker; expect no match.
- Some change paths leave no audit record → change one record through the form, the API, a bulk action, an import and a background job; expect one history entry per change.
- The audit entry stores secrets in its diff → change a password, API key or token, then read the audit entry and the logs; expect the secret and its hash masked.
- Audit entries are editable or forgeable → as a test-instance administrator, send PUT and DELETE to an audit entry, then forge a change's user field; expect refusal and the true actor recorded.
- Undo restores the parent but not its dependents → delete a seeded parent with children and an attachment, undo, then fetch the children, download the file and compare counts and search results.
- Restore collides with newer or missing data → delete a seeded record, create another with its unique value, delete the old record's parent, then restore; expect a clear conflict, not a 500.

## Feature flags and role-dependent behaviour

Applies when: the repository has flag SDKs or tables (LaunchDarkly, Unleash, Flipper, OpenFeature, a `feature_flags` table, `FEATURE_` or `ENABLE_` environment variables), role or permission definitions (role enums, policy classes, CASL, Pundit, cancancan, `@PreAuthorize`, permission decorators), or interface code that renders conditionally on a role or flag.

- Only the interface checks the role or flag → with the flag off, and as a role lacking the permission, call the feature's API endpoints directly with curl; expect 403 or 404.
- Some endpoint-role pairs are unprotected → on a test instance, call every endpoint and method in the route list or OpenAPI file as every role; diff status codes against the permission matrix.
- Responses carry fields the role must not see → as the lowest role, fetch list, detail, export and WebSocket payloads and diff their field names against an administrator's; expect restricted fields absent.
- A revoked or downgraded role keeps access → save a test administrator's token, downgrade or disable that user from another session, then replay the token; expect refusal within the documented delay.
- An end user overrides a flag → as a normal user in a production-like build, send the override the code supports (for example `?feature_x=on` or an `X-Feature` header); expect it ignored.
- A flag service outage exposes unfinished features → in a test instance, block the flag provider's host or start with an invalid SDK key; check each flag against its documented safe default.
- A flag turned off breaks on existing data → enable the flag on a test instance, create data, disable it, then run lists, exports and jobs over that data; expect no 500.
