# Multi-Tenant Email Platform — Architecture

## 1. Purpose and architecture principles

Build a secure, web-first email platform that serves multiple independent organizations (tenants). Each tenant can verify one or more domains, create mailboxes, invite staff, and manage messages. The platform operator manages shared infrastructure while tenant data and permissions remain strictly isolated.

Architecture principles:

- **Tenant isolation first:** every tenant-owned resource is scoped and authorized server-side.
- **One source of truth:** Supabase Postgres owns structured application state; object storage owns attachment bytes.
- **Provider abstraction:** email and object-storage vendors are accessed through replaceable adapters.
- **No hidden replication:** each attachment has one authoritative storage location unless a separately specified backup feature is enabled.
- **Web first:** the initial product is a responsive web dashboard. A future mobile client uses the same APIs and access rules.
- **Documented, verified integrations:** a provider selection is not evidence that an account, DNS record, integration, or production flow is configured.

## 2. High-level system

| Layer | Service | Responsibility |
|---|---|---|
| Web client | React, Vite, TypeScript, Tailwind, shadcn/ui | Tenant dashboard and email UI |
| API/runtime | Cloudflare Workers | Authenticated API, authorization, orchestration, webhooks |
| Identity | Supabase Auth | Sign-in, sessions, identity lifecycle |
| Database | Supabase Postgres | Tenants, memberships, domains, mailboxes, messages, metadata, usage, audit |
| Inbound mail | Cloudflare Email Routing + Email Workers | Receive and dispatch inbound email |
| Outbound mail | Resend | Send, reply, forward |
| Secondary outbound | Brevo | Optional provider adapter / contingency |
| Primary object storage | Cloudflare R2 | Private attachment objects |
| Alternative object storage | Backblaze B2, Tigris, Supabase Storage | Interchangeable provider adapters |

## 3. Multi-tenant domain model

The initial single-school schema must be redesigned before it is applied to any database. The target model should include at least:

- `tenants`: organization/customer account, status, plan, preferences, timestamps.
- `tenant_memberships`: authenticated user-to-tenant relationship, status, role, invitation and approval state.
- `domains`: normalized domain, tenant owner, verification status, DNS verification evidence, inbound/outbound readiness.
- `mailboxes`: tenant-owned email addresses, sender identities, status, display name, settings.
- `mailbox_memberships`: explicit user access and mailbox-level role.
- `messages`: tenant and mailbox ownership, normalized headers, body references/content, thread identifiers, direction, timestamps, status.
- `message_recipients`: from/to/cc/bcc recipient records with normalized addresses and recipient type.
- `threads`: tenant-scoped conversation grouping.
- `attachments`: tenant/message ownership, provider identifier, bucket/container, object key, original filename, safe media type, byte size, checksum, scan/status metadata.
- `drafts`, `folders` or `labels`: tenant/mailbox-scoped message organization.
- `provider_events`: verified inbound/outbound webhook and processing events, idempotency keys, provider references.
- `audit_logs`: actor, tenant, action, resource, timestamp, safe metadata.
- `storage_usage` or a usage ledger: tenant usage accounting and quota enforcement.
- `tenant_plans` / `subscriptions`: plan limits and billing state when monetization is implemented.

Use foreign keys and composite constraints to prevent cross-tenant references (for example, a message cannot point to a mailbox owned by another tenant). Add tenant-aware indexes for common mailbox and message queries. Do not trust a tenant ID, role, mailbox ID, or storage key supplied by the browser without resolving ownership server-side.

### Tenant authorization

1. Verify the Supabase Auth access token on the server.
2. Resolve the active tenant membership from trusted database records.
3. Confirm tenant status and membership status.
4. Confirm mailbox-level permission for the requested operation.
5. Apply tenant-scoped database predicates and object ownership checks.
6. Record security-relevant actions in the audit log.

RLS must provide defense in depth. If a server-side service-role key is used, it bypasses RLS and therefore requires explicit authorization in every server handler. Keep that key only in Worker secrets. Do not expose mailbox or message tables to every authenticated browser user.

## 4. Authentication and account lifecycle

Use Supabase Auth for identity and sessions. Support the agreed sign-in methods only after provider configuration and recovery flows are tested. A signed-in user is not automatically a member of any tenant.

- Tenant creation must establish an owner/admin membership.
- Invitations must be scoped to a tenant and expire.
- Accepting an invitation must verify the intended identity.
- Membership revocation must take effect on subsequent API requests.
- Role changes and sensitive account actions must be audited.
- Public registration must never grant access to an existing tenant or mailbox.
- Do not use editable user metadata as the source of authorization.

## 5. Inbound email flow

1. Tenant submits a domain and completes ownership verification using a generated DNS challenge.
2. The platform records verification status and checks the required MX/TXT records.
3. Configure Cloudflare Email Routing for the verified domain and route matching recipients to the platform's Email Worker.
4. The Email Worker receives the message event and validates envelope recipient, domain mapping, size, and supported content.
5. Resolve the recipient address to exactly one active tenant mailbox. Unknown, suspended, or ambiguous recipients must be rejected or handled by an explicit quarantine policy; never guess a tenant.
6. Parse MIME safely. Preserve required headers and supported plain-text/HTML bodies. Apply attachment count and size limits.
7. Store message data and processing state in Supabase Postgres.
8. Upload attachment bytes through the configured storage adapter using opaque object keys.
9. Persist attachment metadata and storage-provider reference.
10. Mark the message available only after required persistence succeeds. Use idempotency keys so provider retries do not create duplicate messages or attachments.

Cloudflare Email Workers' current runtime limits, raw-message access, MIME handling constraints, retry behavior, and account/domain requirements must be verified during implementation. Design for malformed MIME, duplicate delivery, oversized messages, partial failures, spam, and provider outages.

## 6. Outbound email flow

1. An authenticated member composes a message, reply, or forward.
2. The API verifies tenant membership, mailbox permission, sender identity, verified domain status, recipients, content, attachment ownership, and quotas.
3. The Resend adapter sends the message using server-side credentials and a verified sender domain.
4. Persist the provider message ID, request state, and timestamps. Provider acceptance is not proof of final delivery.
5. Process signed delivery, bounce, and complaint webhooks where available. Verify signatures and use idempotent event processing.
6. Expose clear message states to the UI (for example queued, accepted, delivered, bounced, failed) based on actual provider evidence.

Brevo is a secondary provider adapter, not a second automatic send for every message. Define explicit routing/failover rules to avoid duplicate delivery. Before onboarding external tenants, verify Resend's current plan/domain limits, acceptable-use rules, sender-domain onboarding model, rate limits, and account constraints for a multi-tenant SaaS. If Resend cannot support the intended domain model, reassess the provider architecture before launch.

## 7. Attachment and object-storage architecture

### Responsibilities

- Supabase Postgres stores attachment metadata, ownership, storage provider reference, size, checksum, and lifecycle state.
- Object storage stores the binary attachment bytes.
- Cloudflare Workers mediate uploads, downloads, previews, deletion, and provider access.
- The browser never receives long-lived storage credentials.

### Supported providers

1. Cloudflare R2 — primary.
2. Backblaze B2 — alternative.
3. Tigris — alternative.
4. Supabase Storage — alternative.

Implement a common `StorageProvider` interface with operations equivalent to:

- `putObject` (stream or bounded upload, content type, metadata)
- `getObject` (authorized read/stream)
- `deleteObject`
- `headObject` (size, content type, checksum/metadata)
- `createUploadTarget` / `createDownloadTarget` only where safe and supported
- `copyObject` or `moveObject` for controlled migrations where supported

Normalize provider errors and capabilities. Do not assume every provider supports identical multipart behavior, checksum semantics, object versioning, signed URL behavior, or consistency guarantees. Test the selected SDK and request-signing approach in the Cloudflare Workers runtime.

Each attachment record must identify its authoritative provider and object location. Provider changes require a migration job that copies, verifies checksums/size, updates the database reference atomically, and only then removes the old object after a safe grace period. Do not perform implicit cross-provider failover that can orphan objects.

### Cloudflare account and bucket model

- Operate one Cloudflare account for the platform.
- Use one private shared R2 bucket per environment (for example, staging and production), not one bucket per tenant by default.
- Use opaque tenant-scoped object keys such as `tenants/{tenant_id}/attachments/{object_id}`.
- A prefix is organizational, not an authorization boundary. Every access still requires database ownership and tenant membership checks.
- Do not create multiple Cloudflare accounts to multiply free-tier allowances.
- Configure lifecycle rules only when they match the approved retention policy.
- Monitor actual account-level storage and operation usage.

### Tenant quotas

Quotas are logical per-tenant limits over shared physical storage. For example, each tenant may receive a plan allowance, but billing is based on aggregate provider usage, not the sum of reserved quotas. Enforce quota checks transactionally to prevent concurrent uploads exceeding the allowance. Track pending uploads and deleted/trash bytes accurately. Warn at configurable thresholds (suggested 80% and 95%) and provide clear usage reporting.

### Retention and deletion

Do not silently delete customer attachments after an arbitrary age. Define tenant-configurable retention, user-initiated deletion, trash/grace periods, legal/administrative holds if required, and eventual object cleanup. A local device download or browser cache must not be the sole archive copy.

## 8. Provider selection and current constraints

- R2 is the selected primary because of its 10 GB-month Standard storage free allowance and no internet egress fees, subject to account billing activation and current plan terms.
- Backblaze B2 offers the first 10 GB free under its current published pricing and is an S3-compatible alternative.
- Tigris offers 5 GB Standard storage free per month, with published request allowances and no egress fees.
- Supabase Storage offers 1 GB on the Free plan; it is convenient for integration but should not be assumed to provide large attachment capacity.
- Free allowances are provider/account-level, can change, and are not a contractual production capacity guarantee. Never promise tenants a specific free allowance as a permanent product feature.

Verify pricing, account eligibility, payment requirements, data residency, limits, and terms at the time each provider is activated.

## 9. Search, threading, and message rendering

- Keep message search tenant-scoped and mailbox-authorized.
- Normalize email addresses and headers while preserving raw values needed for display/audit.
- Threading must handle missing or malformed `Message-ID`, `In-Reply-To`, and `References` headers.
- Render untrusted HTML with a sanitizer and restrictive sandbox; do not execute scripts.
- Block remote images and external resources by default, with an explicit user action to load them.
- Treat filenames, headers, links, and message bodies as untrusted input.

## 10. Observability and operations

Record structured, privacy-safe events for inbound processing, outbound sends, provider webhooks, storage operations, quota changes, and failures. Include correlation IDs and tenant IDs only where safe. Do not log message content, credentials, access tokens, or attachment bytes.

Provide:
- Idempotent processing and retry/dead-letter handling.
- Provider health and quota monitoring.
- Tenant storage usage and alerting.
- Safe operational tooling for reprocessing failed events.
- Documented backup, restore, and object migration procedures.
- Alerts for unexpected storage growth, send failures, webhook signature failures, and inbound processing failures.

## 11. Web-first, mobile-later

The initial release is a responsive web application. Keep business logic in authenticated API endpoints rather than embedding authorization in UI state. A later mobile client may use React Native/Expo or another framework, but it must share the same identity, tenant membership, API, and object authorization model.

## 12. Implementation gates

Do not implement full email functionality until:
1. The single-school schema has been redesigned for tenants and reviewed.
2. RLS and server authorization have been tested against cross-tenant access attempts.
3. Storage provider interface and R2 adapter contracts are agreed.
4. Inbound Cloudflare runtime limits and Resend multi-domain feasibility are verified.
5. Domain verification and tenant onboarding threat models are documented.

See [IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md), [STORAGE-STRATEGY.md](STORAGE-STRATEGY.md), and [SECURITY-AND-OPEN-DECISIONS.md](SECURITY-AND-OPEN-DECISIONS.md).
