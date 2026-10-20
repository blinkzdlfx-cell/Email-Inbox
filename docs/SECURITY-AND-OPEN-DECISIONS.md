# Security and Open Decisions

Updated: 2026-10-20

## Confirmed

| Item | Decision |
|---|---|
| School domain | `bukanabriliantschools.com` |
| Shared mailbox | `info@bukanabriliantschools.com` |
| Mailbox model | One shared school inbox for explicitly authorized staff |
| Staff sign-in methods | Supabase Auth: Google sign-in and email/password |
| Frontend direction | React, Vite, TypeScript, Tailwind CSS, shadcn/ui |
| Database | Supabase Postgres |
| Attachment storage | Backblaze B2 through its S3-compatible API; private bucket |
| Inbound direction | Cloudflare Email Worker, pending feasibility/configuration checks |
| Outbound direction | Brevo API, pending policy/deliverability suitability checks |

## Security invariants

1. Login and mailbox authorization are separate. Authentication alone never grants access to the school mailbox.
2. Public registration, if enabled for technical reasons, must not grant access until an administrator explicitly approves the staff identity.
3. All mailbox data operations and attachment downloads are authorized on the server.
4. All secrets stay in server-side environment bindings/secrets; never use frontend-exposed variables for secrets.
5. Email bodies and attachments are untrusted input. Render HTML in a restrictive sandbox/sanitized view and block remote images by default.
6. Use parameterized SQL, request validation, send quotas/rate limits, webhook verification, and audit records.
7. Audit who sent, replied, forwarded, downloaded, or changed messages, without logging full message content or credentials.
8. Provider acceptance is not delivery confirmation. Store provider state accurately and process verified callbacks idempotently.
9. Keep the Backblaze B2 bucket private and authorize every attachment operation through the Worker.
10. Enable RLS on application tables. Do not expose mailbox data to all authenticated users merely because they can sign in.
11. Never put real credentials, private message samples, or personal data in this public repository.

## Open decisions — blockers before production

| Priority | Question / check | Why it matters |
|---|---|---|
| P0 | Confirm a school administrator controls the domain's DNS and can change MX/TXT/CNAME records. | Required for inbound routing and sender authentication. |
| P0 | Confirm Cloudflare account/domain availability and Email Worker support/limits for the intended receiving flow. | A forwarding-only setup is not a complete shared inbox. |
| P0 | Verify Brevo allows and reliably supports ordinary human correspondence from this shared inbox; confirm account sending limits and domain authentication. | Transactional API suitability must not be assumed. |
| P0 | Create/confirm a dedicated Supabase project and test its database/Auth configuration. | Prevents accidental use of an unrelated project and confirms required capabilities. |
| P0 | Configure Supabase Auth Google OAuth, allowed redirect URLs, email verification, and password recovery. | Required for secure sign-in and account recovery. |
| P0 | Create a private Backblaze B2 bucket and a restricted application key; test S3-compatible access from a Worker. | Attachment uploads and downloads must remain private. |
| P0 | Configure production email delivery for Supabase verification and password-reset messages. | Authentication emails need reliable delivery and domain alignment. |
| P1 | Confirm the approved staff roster and who can invite/approve/deactivate accounts. | Prevents unauthorized staff from entering the shared mailbox. |
| P1 | Decide staff roles (administrator, sender, read-only) and who can manage users. | Defines least-privilege access. |
| P1 | Decide whether read/unread state is shared globally or per staff member. | Changes database model and UI behavior. |
| P1 | Decide retention/deletion rules, attachment size limits, and backup/recovery expectations. | School correspondence may contain sensitive records. |
| P1 | Confirm whether the sender should always be `info@bukanabriliantschools.com` and what reply-to identity is required. | Avoids sender impersonation and reply confusion. |
| P1 | Confirm deployment origin and whether staff may access the app from preview deployments. | Controls trusted auth origins and CORS. |
| P2 | Decide whether notifications are required for first release. | FCM remains deferred until core mail works. |

## Authentication

Supabase Auth is the selected provider for Google sign-in and email/password, but it is not yet configured. Set the site's canonical URL and exact allowed redirect URLs, configure Google OAuth, enable appropriate email verification and password recovery, and use production-grade email delivery. Do not allow sign-up alone to grant mailbox access. Application staff approval and role checks remain separate.

## Secrets/configuration checklist

Use placeholders only in tracked examples. Store actual values in Cloudflare secrets and ignored local development files.

- Supabase project URL and publishable key for browser-safe Auth operations
- Supabase secret/service-role key only as a server-side Worker secret if needed; never expose it to the browser
- Backblaze B2 bucket name, S3-compatible endpoint/region, key ID, and application key as server-side configuration/secrets
- Brevo API key
- Google OAuth credentials configured through Supabase Auth
- Verified webhook secret/signature configuration
- FCM credentials only if notifications are later enabled

Never send secrets in chat, place them in frontend source, or commit them.

## Initial database schema

The migration is at `db/migrations/0001_shared_mailbox.sql`. It must use PostgreSQL syntax suitable for the dedicated Supabase project. It defines the shared mailbox, staff identity mapping and approval status, explicit mailbox roles, messages, recipients, attachment metadata, audit events, and provider events. It seeds the logical school mailbox only; it does not configure DNS or create a real mail account.

The migration has not been applied to any database. Review the RLS posture and permissions, then apply it only to the dedicated Bukana Supabase project. Do not apply it to any unrelated project. Retention, attachment limits, shared-vs-per-user read state, and exact provider status transitions still require decisions.

## Current verification status

- Repository documentation and initial scaffold: committed; local build/test status still needs confirmation.
- DNS/domain ownership: not verified.
- Supabase project/database/Auth: selected but not configured or verified.
- Backblaze B2 bucket/credentials: selected but not provisioned or verified.
- Inbound email: not implemented or tested.
- Outbound email: not implemented or tested.
- Production deployment: not implemented or verified.
