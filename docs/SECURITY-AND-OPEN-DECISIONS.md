# Security and Open Decisions

Updated: 2026-10-20

## Confirmed

| Item | Decision |
|---|---|
| School domain | `bukanabriliantschools.com` |
| Shared mailbox | `info@bukanabriliantschools.com` |
| Mailbox model | One shared school inbox for explicitly authorized staff |
| Staff sign-in methods | Google sign-in and email/password |
| Frontend direction | React, Vite, TypeScript, Tailwind CSS, shadcn/ui |
| Database direction | Neon Postgres |
| Inbound direction | Cloudflare Email Worker, pending feasibility/configuration checks |
| Outbound direction | Brevo API, pending policy/deliverability suitability checks |
| Attachment direction | Private Cloudflare R2 bucket |

## Security invariants

1. Login and mailbox authorization are separate. Authentication alone never grants mailbox access.
2. Public registration, if enabled for technical reasons, must not grant access until an administrator explicitly approves the staff identity.
3. All mailbox data operations and attachment downloads are authorized on the server.
4. All secrets stay in server-side environment bindings/secrets; never use frontend-exposed variables for secrets.
5. Email bodies and attachments are untrusted input. Render HTML in a restrictive sandbox/sanitized view and block remote images by default.
6. Use parameterized SQL, request validation, send quotas/rate limits, webhook verification, and audit records.
7. Audit who sent, replied, forwarded, downloaded, or changed messages, without logging full message content or credentials.
8. Provider acceptance is not delivery confirmation. Store provider state accurately and process verified callbacks idempotently.
9. Keep R2 private and validate access for every attachment operation.
10. Never put real credentials, private message samples, or personal data in this public repository.

## Open decisions — blockers before production

| Priority | Question / check | Why it matters |
|---|---|---|
| P0 | Confirm a school administrator controls the domain's DNS and can change MX/TXT/CNAME records. | Required for inbound routing and sender authentication. |
| P0 | Confirm Cloudflare account/domain availability and Email Worker support/limits for the intended receiving flow. | A forwarding-only setup is not a complete shared inbox. |
| P0 | Verify Brevo allows and reliably supports ordinary human correspondence from this shared inbox; confirm account sending limits and domain authentication. | Transactional API suitability must not be assumed. |
| P0 | Inspect the Neon project's region and networking settings to determine whether Neon Auth (managed Better Auth) is eligible. | Managed Neon Auth has project eligibility constraints. |
| P0 | Create/configure the school's own Google OAuth client and trusted redirect origins if Neon Auth is selected. | Google sign-in cannot work without correct provider setup. Never commit client secrets. |
| P0 | Select production SMTP/email delivery for verification and password reset. | Authentication emails need reliable delivery and domain alignment; shared development SMTP is not a production configuration. |
| P1 | Confirm the approved staff roster and who can invite/approve/deactivate accounts. | Prevents unauthorized staff from entering the shared mailbox. |
| P1 | Decide staff roles (administrator, sender, read-only) and who can manage users. | Defines least-privilege access. |
| P1 | Decide whether read/unread state is shared globally or per staff member. | Changes database model and UI behavior. |
| P1 | Decide retention/deletion rules, attachment size limits, and backup/recovery expectations. | School correspondence may contain sensitive records. |
| P1 | Confirm whether the sender should always be `info@bukanabriliantschools.com` and what reply-to identity is required. | Avoids sender impersonation and reply confusion. |
| P1 | Confirm deployment origin and whether staff may access the app from preview deployments. | Controls trusted auth origins and CORS. |
| P2 | Decide whether notifications are required for first release. | FCM remains deferred until core mail works. |

## Authentication candidate

Neon Auth (managed Better Auth) is the current candidate because the project requires email/password plus Google sign-in. It is **not yet configured or verified**. Check the Neon project is eligible (including region/network restrictions), then configure the production Google OAuth application, trusted application origins, and production SMTP. If these conditions are not met, document the replacement auth approach before writing auth-specific endpoints.

## Secrets/configuration checklist

Use placeholders only in tracked examples. Store actual values in Cloudflare secrets/bindings and local ignored development files.

- Neon server connection configuration
- Brevo API key
- Google OAuth client secret (if Neon Auth is selected)
- Auth/session configuration required by the selected provider
- R2 bucket binding and credentials only if the chosen access pattern requires them
- Verified webhook secret/signature configuration
- FCM credentials only if notifications are later enabled

Never send secrets in chat, place them in frontend source, or commit them.

## Current verification status

- Repository documentation: recorded.
- DNS/domain ownership: not verified.
- Authentication: requirements recorded; provider not configured.
- Database/R2/Cloudflare bindings: not verified.
- Inbound email: not implemented or tested.
- Outbound email: not implemented or tested.
- Production deployment: not implemented or verified.
