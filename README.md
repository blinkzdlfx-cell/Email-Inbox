# Multi-Tenant Email Platform

A secure, web-first email platform for multiple organizations. Each customer (tenant) can connect verified domains, create mailboxes, invite staff, and manage email through an isolated workspace.

> **Status:** Planning and scaffold stage. This repository is not yet a production email service. Provider accounts, DNS, authentication, database migrations, storage adapters, inbound processing, outbound sending, and deployment must be implemented and verified before launch.

## Product direction

- Multi-tenant SaaS: multiple organizations share the platform while their users, domains, mailboxes, messages, attachments, settings, and usage remain isolated.
- Web dashboard first; mobile application is a later phase using the same backend and authorization model.
- Tenant onboarding must verify domain ownership before enabling a domain for mail.
- The platform operator controls the infrastructure. Tenants do not need their own Cloudflare accounts.

## Agreed infrastructure

| Responsibility | Selected service | Role |
|---|---|---|
| Web application | React, Vite, TypeScript, Tailwind CSS, shadcn/ui | Responsive email dashboard |
| Backend/API | Cloudflare Workers | Authenticated API, orchestration, inbound email processing |
| Inbound email | Cloudflare Email Routing + Email Workers | Receive and process messages for verified tenant domains |
| Outbound email | Resend | Send, reply, and forward through verified sender domains |
| Secondary outbound provider | Brevo | Contingency/alternative adapter; not an automatic duplicate sender |
| Authentication | Supabase Auth | User identity and sessions |
| Primary database | Supabase Postgres | Tenant, domain, mailbox, message, membership, audit, and usage records |
| Primary attachment storage | Cloudflare R2 | Private object storage |
| Alternative attachment storage | Backblaze B2, Tigris, Supabase Storage | Supported interchangeable storage adapters |
| Notifications | Deferred | Consider only after core email flows are reliable |

## Storage decision

The application will support four interchangeable object-storage providers:

1. **Cloudflare R2 — primary**
2. **Backblaze B2 — supported alternative**
3. **Tigris — supported alternative**
4. **Supabase Storage — supported alternative**

These providers are not intended to receive four copies of every attachment. The application will use a storage-provider interface and store the provider, bucket/container, object key, size, checksum, and metadata for each object. One provider stores each attachment as its authoritative copy unless a separately designed backup/replication feature is approved.

Use one Cloudflare account operated by the platform owner, with a shared private R2 bucket per environment (for example, staging and production). Tenant-specific prefixes and database-enforced quotas provide logical separation. Do not create additional Cloudflare accounts to multiply free allowances.

Provider selection, migration, and failover must be explicit and auditable. Never silently switch providers after an upload failure in a way that leaves an attachment reference ambiguous.

## Email flow

### Incoming

1. A tenant proves control of a domain through the documented DNS verification process.
2. The platform configures the supported Cloudflare Email Routing rules for that domain.
3. A Cloudflare Email Worker receives the message.
4. The Worker resolves the envelope recipient to a verified tenant and mailbox, validates limits, and processes MIME content.
5. Message headers, bodies, recipients, thread data, and processing state are persisted in Supabase Postgres.
6. Attachment bytes are written to the configured private storage provider; metadata and provider object references are stored in Postgres.
7. The message becomes available only to authorized members of that tenant.

### Outgoing

1. An authorized tenant member composes, replies, or forwards.
2. The backend verifies tenant membership, mailbox permissions, sender-domain verification, recipient policy, and usage limits.
3. Resend sends the message using server-side credentials.
4. Provider message IDs and lifecycle states are persisted.
5. Verified, idempotently processed webhooks update delivery, bounce, and complaint status where supported.
6. Brevo may be used as a separately configured alternative if Resend is unavailable or unsuitable. Do not automatically send the same message through both providers.

Resend's domain limits, account policy, inbound/outbound quotas, and multi-tenant custom-domain onboarding constraints must be verified before commercial onboarding. Never promise unrestricted custom domains based solely on a free plan.

## Multi-tenant security invariants

- Every tenant-owned record has a tenant identifier and tenant-scoped constraints.
- The server derives tenant access from the authenticated user's membership; never trust a tenant ID supplied by the browser.
- Enforce tenant authorization on every API operation, message query, search, attachment upload, preview, download, delete, and provider callback.
- Use PostgreSQL Row Level Security as defense in depth. Server-side privileged credentials remain secret and do not replace explicit authorization checks.
- Use opaque object keys and tenant-scoped storage paths. A path prefix is not an authorization mechanism.
- Never expose storage credentials, provider API keys, Supabase service-role keys, or webhook secrets to the browser.
- Verify webhook signatures and process events idempotently.
- Safely render untrusted HTML email; block remote content by default and do not execute scripts.
- Audit sensitive actions without logging message bodies, credentials, or attachment contents.

## Storage and retention principles

- Email bodies and structured metadata belong in Postgres; binary attachments belong in object storage.
- The database is the source of truth for object ownership and references.
- Do not silently delete attachments after an arbitrary 30- or 90-day period.
- Provide tenant-configurable retention policies, quota warnings, attachment deletion, and a recoverable trash/grace period where appropriate.
- Device downloads or browser caches are conveniences, not the only copy of a customer's email archive.
- Enforce tenant quotas against actual usage in the shared storage pool; provider free allowances are account-level and can change.
- Add usage alerts and a hard/soft quota policy before production.

## Repository documents

- [Architecture](docs/ARCHITECTURE.md)
- [Implementation plan](docs/IMPLEMENTATION-PLAN.md)
- [Security and open decisions](docs/SECURITY-AND-OPEN-DECISIONS.md)
- [Storage strategy and provider adapters](docs/STORAGE-STRATEGY.md)

## Current implementation status

The repository began as a single-school shared inbox scaffold. Its existing database migration and school-specific copy are not a production-ready multi-tenant schema. The next engineering stage must generalize the product model, replace school-specific assumptions, review the database design and RLS policies, and implement integrations incrementally.

Do not treat any provider as configured merely because it is named in these documents. No production mail flow, storage adapter, tenant isolation, or deployment is verified until implementation and controlled tests pass.

## Secrets and configuration

Keep all provider credentials server-side in Cloudflare Worker secrets/bindings or an approved secret manager. Use ignored local development files for local secrets. Tracked examples must contain placeholders only. Never put secrets in `VITE_*` variables or commit credentials.
