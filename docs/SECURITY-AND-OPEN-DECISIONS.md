# Security, Decisions, and Verification Register

Updated: 2026-11-17

## 1. Confirmed product and infrastructure decisions

| Area | Decision |
|---|---|
| Product model | Multi-tenant email platform for multiple organizations |
| Delivery order | Web dashboard first; mobile application later |
| Frontend | React, Vite, TypeScript, Tailwind CSS, shadcn/ui |
| Backend/runtime | Cloudflare Workers |
| Identity | Supabase Auth |
| Structured database | Supabase Postgres |
| Inbound email | Cloudflare Email Routing + Email Workers |
| Primary outbound email | Resend |
| Secondary outbound option | Brevo, subject to feasibility and policy checks |
| Primary attachment storage | Cloudflare R2 |
| Alternative attachment storage | Backblaze B2, Tigris, Supabase Storage |
| Cloudflare account model | One platform-owner Cloudflare account; no multi-account free-tier strategy |
| Storage topology | One private shared R2 bucket per environment by default, tenant-scoped object keys and quotas |
| Attachment replication | Not selected for first release; one authoritative provider/object per attachment |
| Retention | No silent arbitrary 30/90-day deletion; tenant/user-controlled retention policy required |

These are architectural selections, not proof that any provider account, domain, DNS record, bucket, credential, or integration has been configured.

## 2. Tenant-isolation security invariants

1. Every tenant-owned record must be associated with a tenant.
2. Every API request must authenticate the user and resolve active tenant membership from trusted server-side records.
3. Never trust a tenant ID, mailbox ID, role, object key, or storage provider supplied by the browser as proof of authorization.
4. Enforce tenant and mailbox authorization for every read, write, search, send, upload, preview, download, and delete operation.
5. Use tenant-aware foreign keys/constraints to prevent cross-tenant references.
6. Enable RLS on tenant-owned tables and test it. If privileged server credentials bypass RLS, explicit server authorization remains mandatory.
7. Authentication does not automatically grant membership in any tenant.
8. Invitations must be tenant-scoped, time-limited, and tied to the intended identity.
9. Revoked memberships must lose access on subsequent API requests.
10. Audit sensitive actions without recording full message bodies, credentials, access tokens, or attachment contents.

## 3. Storage security invariants

1. R2 is the primary attachment store; Backblaze B2, Tigris, and Supabase Storage are alternative adapters.
2. Do not automatically duplicate all objects across all providers.
3. Each attachment has one authoritative provider/container/object reference recorded in the database.
4. Keep all provider credentials server-side in Cloudflare Worker secrets/bindings or an approved secret manager.
5. Keep buckets/containers private. Never expose permanent public object URLs or storage credentials.
6. Use opaque tenant-scoped object keys. Prefixes are not authorization boundaries.
7. Authorize every attachment operation against database ownership and current tenant/mailbox permissions.
8. Validate actual upload size, allowed types, content where practical, and safe download headers.
9. Use short-lived signed URLs only when the authorization and expiry model has been reviewed.
10. Provider migrations must copy, verify, update references, retain a rollback window, and only then delete old objects.
11. Enforce tenant quotas with race-safe accounting and reconcile database usage against actual objects.
12. Do not silently delete attachments after an arbitrary fixed age.

## 4. Email security invariants

- Verify tenant domain ownership before enabling inbound or outbound mail for that domain.
- Resolve inbound recipients to exactly one active tenant mailbox. Unknown or ambiguous recipients must not be assigned by guesswork.
- Parse MIME defensively and enforce message/attachment limits.
- Make inbound processing idempotent to handle provider retries.
- Verify outbound provider webhook signatures and process events idempotently.
- Provider acceptance is not proof of delivery.
- Prevent sender spoofing by checking mailbox ownership and verified sender domains.
- Apply tenant-level and mailbox-level send quotas and abuse controls.
- Render email HTML in a restrictive sanitized view; never execute scripts.
- Block remote images and external content by default.
- Treat headers, filenames, links, and body content as untrusted input.
- Avoid logging email bodies, tokens, credentials, or attachment bytes.

## 5. Provider decisions and constraints to verify

| Provider | Selected role | Published free allowance currently observed | Verification required |
|---|---|---:|---|
| Cloudflare R2 | Primary object storage | 10 GB-month Standard, 1M Class A, 10M Class B; internet egress free | Account billing activation, payment method/account eligibility, limits, Workers runtime integration |
| Backblaze B2 | Alternative object storage | First 10 GB free | Account registration, application key, egress/transaction terms, S3-compatible Worker tests |
| Tigris | Alternative object storage | 5 GB Standard/month; published request allowances and no egress fees | Account eligibility, region/data residency, request limits, Worker tests |
| Supabase Storage | Alternative object storage | 1 GB on Free plan | Project coupling, upload size limits, egress, quota behavior |
| Resend | Primary outbound email | Plan-dependent | Domain limits, multi-tenant custom-domain onboarding, account policies, sending limits, webhooks, reply/forward suitability |
| Brevo | Secondary outbound email | Plan-dependent | Human correspondence suitability, sender policies, domain authentication, rate limits, webhook support |
| Cloudflare Email Routing/Workers | Inbound email | Depends on current account/Workers product limits | Runtime limits, message size, MIME access, routing behavior, retries, account/domain requirements |

Free-tier allowances are subject to provider changes, eligibility, billing activation, geography, and acceptable-use terms. They must not be represented as permanent customer entitlements. Recheck official provider documentation before implementation and launch.

## 6. Open decisions — blockers before production

| Priority | Question / verification | Why it matters |
|---|---|---|
| P0 | Finalize tenant onboarding, tenant owner/admin roles, and tenant lifecycle. | Core SaaS access model. |
| P0 | Redesign the existing single-school SQL migration into a tenant-aware schema. | Current migration must not be applied as-is to production. |
| P0 | Review RLS, server authorization, composite constraints, and cross-tenant tests. | Prevents tenant data leakage. |
| P0 | Verify Cloudflare Email Worker runtime/message limits and inbound domain routing behavior. | Required for a durable inbound inbox. |
| P0 | Verify Resend custom-domain and multi-tenant onboarding constraints. | Determines whether Resend can support customer-owned domains at the intended scale. |
| P0 | Verify sender-domain authentication and outbound webhook signatures. | Deliverability and trustworthy status tracking. |
| P0 | Create/verify the platform-owned Cloudflare account and R2 activation path. | Required for the primary storage adapter. |
| P0 | Define storage adapter contract and test R2 in Workers. | Prevents provider-specific coupling and runtime surprises. |
| P0 | Define maximum email and attachment sizes, quotas, and upload concurrency. | Prevents abuse and unexpected cost. |
| P0 | Define domain verification and safe DNS onboarding. | Prevents unauthorized domain/mailbox claims. |
| P1 | Verify Backblaze B2 account registration and credentials. | Enables a tested alternative provider. |
| P1 | Verify Tigris account and runtime compatibility. | Enables a tested alternative provider. |
| P1 | Decide when Supabase Storage is useful relative to its smaller free quota. | Avoid unnecessary provider coupling. |
| P1 | Decide tenant plan quotas and usage warning thresholds. | Required for predictable cost and customer expectations. |
| P1 | Decide retention, trash/grace period, export, and permanent deletion rules. | Email may be business-critical records. |
| P1 | Decide spam/quarantine and abuse review workflows. | Protects tenants and sending reputation. |
| P1 | Decide shared vs per-user read/unread state and mailbox roles. | Affects schema and UX. |
| P2 | Decide whether notifications are needed in the first release. | Keep nonessential complexity deferred. |
| P2 | Select future mobile technology after web API stability. | Avoid premature platform work. |

## 7. Existing repository artifacts requiring review

The repository originally started as a single-school inbox scaffold. The existing `db/migrations/0001_shared_mailbox.sql` and any school-specific UI, fixtures, seed data, or environment names are not automatically compatible with the multi-tenant product.

Before applying any migration:
- Inspect and redesign the schema for tenants and tenant memberships.
- Remove school-specific assumptions unless intentionally retained as a sample/demo tenant fixture.
- Review all policies and grants.
- Add tests for cross-tenant query and object access.
- Confirm the target Supabase project is the intended project.
- Apply only after review and explicit project confirmation.

Do not apply the old migration to an unrelated or production database.

## 8. Secrets and configuration checklist

Use placeholders only in tracked examples. Store real values in Cloudflare secrets/bindings or an approved secret manager.

- Supabase project URL and publishable key for browser-safe operations.
- Supabase secret/service-role key only server-side if required; never expose it to the browser.
- Resend API key and webhook signing secret.
- Brevo API key and webhook verification configuration, if enabled.
- Cloudflare Email Worker and routing configuration.
- R2 bucket/binding configuration and any required credentials.
- Backblaze B2 S3-compatible endpoint, key ID, and application key, if enabled.
- Tigris endpoint and credentials, if enabled.
- Supabase Storage project/bucket configuration, if enabled.
- Local development values in ignored files only.

Never paste secrets into chat, commit them, place them in frontend source, or expose them through `VITE_*` variables.

## 9. Verification status

| Component | Status |
|---|---|
| Updated product/architecture documentation | Committed to main in this documentation pass |
| Existing application scaffold | Exists; requires review against multi-tenant direction |
| Existing SQL migration | Single-school design; must be redesigned before use |
| Supabase Auth/Postgres | Selected; configuration and production behavior not verified here |
| Cloudflare Workers | Selected; production deployment and bindings not verified here |
| Cloudflare Email Routing/Email Worker | Selected; implementation and end-to-end behavior not verified |
| Resend outbound | Selected primary; account/domain onboarding and end-to-end sending not verified |
| Brevo alternative | Documented; not configured or tested |
| Cloudflare R2 | Selected primary; bucket/account activation and adapter not verified |
| Backblaze B2 | Documented alternative; account access and adapter not verified |
| Tigris | Documented alternative; account access and adapter not verified |
| Supabase Storage | Documented alternative; adapter not implemented or verified |
| Tenant isolation | Not implemented or security-tested |
| Production deployment | Not verified |

Documentation does not imply implementation. Update this table only when evidence from actual configuration and tests is available.
