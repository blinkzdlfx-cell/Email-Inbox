# Implementation Plan

## Delivery principles

- Plan and verify before implementing provider-specific behavior.
- Build the multi-tenant security foundation before exposing inbox data.
- Keep provider adapters replaceable; avoid coupling product logic to vendor SDKs.
- Do not mark an integration complete until it has passed controlled end-to-end tests.
- The first release is a responsive web application. Mobile is a later phase.
- No production secrets, customer message samples, or personal data belong in Git.

## Stage 0 — Product and repository alignment

- [x] Confirm repository and default branch.
- [x] Record the multi-tenant product direction.
- [x] Select Supabase Auth and Supabase Postgres for identity and structured data.
- [x] Select Cloudflare Workers for the API/runtime.
- [x] Select Cloudflare Email Routing and Email Workers for inbound email, subject to feasibility tests.
- [x] Select Resend as primary outbound provider and Brevo as a secondary alternative.
- [x] Select Cloudflare R2 as primary attachment storage.
- [x] Record Backblaze B2, Tigris, and Supabase Storage as interchangeable alternative storage adapters.
- [x] Record one Cloudflare account operated by the platform owner; no multi-account free-tier strategy.
- [x] Document provider abstraction, tenant quotas, retention principles, and migration expectations.
- [ ] Review and remove remaining school-specific assumptions from source, seed data, UI, and database migration.
- [ ] Confirm final product name, tenant onboarding flow, initial plan limits, and operator/admin roles.

## Stage 1 — Architecture and security foundation

- [ ] Redesign the existing single-school database migration for tenants, memberships, domains, mailboxes, messages, recipients, threads, attachments, provider events, audit logs, and usage.
- [ ] Define composite tenant-aware foreign keys, indexes, uniqueness rules, and deletion behavior.
- [ ] Design and review RLS policies for every tenant-owned table.
- [ ] Implement server-side Supabase Auth verification and tenant membership resolution.
- [ ] Implement role and mailbox authorization; do not trust tenant IDs or roles from the browser.
- [ ] Add cross-tenant authorization tests before exposing any tenant data.
- [ ] Define tenant creation, domain verification, invitations, membership revocation, and account recovery.
- Acceptance: automated tests prove that users cannot access another tenant's records, mailboxes, or attachments by changing IDs or request parameters.

## Stage 2 — Storage abstraction and attachment lifecycle

- [ ] Define the application-owned `StorageProvider` interface and normalized error/capability model.
- [ ] Implement Cloudflare R2 adapter first.
- [ ] Configure one private R2 bucket per environment under one platform-owned Cloudflare account.
- [ ] Implement opaque tenant-scoped object keys and database-backed object ownership.
- [ ] Implement upload, head/metadata, download/preview, deletion, quota accounting, and orphan cleanup.
- [ ] Test R2 access from the Cloudflare Workers runtime, including large/interrupted uploads and retries.
- [ ] Implement Backblaze B2 adapter after account registration and credentials are available.
- [ ] Implement Tigris adapter after account and runtime verification.
- [ ] Implement Supabase Storage adapter as an alternative, respecting its plan/upload constraints.
- [ ] Implement an explicit, verified provider migration job before offering provider switching.
- [ ] Define tenant retention, trash/grace period, quota warnings, and permanent deletion policy.
- Acceptance: each adapter passes the same contract tests; unauthorized cross-tenant attachment operations fail; object metadata and stored bytes reconcile.

## Stage 3 — Domain onboarding and inbound email

- [ ] Design domain ownership verification with generated DNS challenges.
- [ ] Verify Cloudflare Email Routing and Email Worker support, account requirements, message limits, retries, and MIME access.
- [ ] Implement verified-domain routing and recipient-to-tenant/mailbox resolution.
- [ ] Implement safe MIME parsing, attachment limits, duplicate detection, and idempotent processing.
- [ ] Persist message metadata and body in Supabase Postgres.
- [ ] Persist attachment bytes through the configured storage adapter.
- [ ] Add authorized inbox listing, search, message detail, and thread APIs.
- [ ] Add quarantine/rejection behavior for unknown recipients, suspended tenants, malformed messages, and abuse.
- Acceptance: a controlled inbound message reaches exactly the intended tenant mailbox, with body and attachments intact; retries do not duplicate messages; cross-tenant access tests pass.

## Stage 4 — Outbound email

- [ ] Verify Resend multi-tenant custom-domain onboarding, domain limits, plan constraints, rate limits, and acceptable-use rules.
- [ ] Implement a provider-neutral outbound email interface.
- [ ] Implement Resend send, reply, and forward flows.
- [ ] Persist provider message IDs and accurate lifecycle states.
- [ ] Verify webhook signatures and process delivery/bounce/complaint events idempotently.
- [ ] Define explicit Brevo alternative/failover policy; do not send duplicate copies automatically.
- [ ] Add tenant and mailbox sending quotas, abuse controls, and sender identity checks.
- Acceptance: authorized test messages send from verified domains; delivery status reflects provider evidence; provider failures and retries do not create unintended duplicates.

## Stage 5 — Web dashboard

- [ ] Build tenant onboarding and organization settings.
- [ ] Build domain verification and mailbox management screens.
- [ ] Build member invitations, roles, and access management.
- [ ] Build responsive inbox, message detail, search, threads, sent mail, drafts, compose, reply, and forward.
- [ ] Add attachment preview/download/delete and storage usage indicators.
- [ ] Add safe HTML/plain-text rendering and remote-content controls.
- [ ] Add loading, empty, error, and provider-outage states.
- Acceptance: core workflows are usable on desktop and mobile browsers and every UI action is enforced by the API.

## Stage 6 — Operations, billing, and optional mobile

- [ ] Add privacy-safe observability, provider health, usage monitoring, and alerting.
- [ ] Add tenant plan/quota enforcement and usage reporting.
- [ ] Document key rotation, provider migration, data export, backup, restore, and incident procedures.
- [ ] Run restore and migration drills.
- [ ] Evaluate mobile application architecture only after web APIs and authorization are stable.
- [ ] Add push notifications only after core email workflows are reliable.
- Acceptance: operations are reproducible, cost/usage limits are visible, and recovery procedures have been tested.

## Stage 7 — Production readiness

- [ ] Run unit, integration, security, type-check, and production build checks.
- [ ] Test domain verification and real inbound/outbound email using controlled domains and recipients.
- [ ] Test cross-tenant data access, attachment access, role revocation, malformed input, spam/abuse limits, and provider outages.
- [ ] Verify DNS, sender authentication, secrets, production bindings, and webhook signatures.
- [ ] Verify storage usage accounting and retention/deletion behavior.
- [ ] Publish deployment, support, recovery, and known-limitations documentation.
- Acceptance: a release report clearly separates implemented, tested, configured, and still-pending capabilities.

## Explicit non-goals for the first release

- No multiple Cloudflare accounts to multiply free storage allowances.
- No automatic four-provider duplication of every attachment.
- No automatic deletion of customer attachments after an arbitrary fixed period.
- No mobile app before the web product and API security model are stable.
- No assumption that a provider's free tier is permanent or sufficient for production.

See [ARCHITECTURE.md](ARCHITECTURE.md), [STORAGE-STRATEGY.md](STORAGE-STRATEGY.md), and [SECURITY-AND-OPEN-DECISIONS.md](SECURITY-AND-OPEN-DECISIONS.md).
