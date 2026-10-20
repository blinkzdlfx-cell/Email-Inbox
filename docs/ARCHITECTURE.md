# Bukana Email Inbox — Architecture

## Goal and confirmed configuration

Build a reliable, secure email interface for Bukana Brilliant Schools.

- Domain: `bukanabriliantschools.com`
- Shared mailbox: `info@bukanabriliantschools.com`
- Mailbox model: one shared school inbox for authorized staff
- Authentication requirement: both Google sign-in and email/password

These are user-confirmed application decisions, not proof that DNS or the mailbox has been configured.

## Inbound email flow

1. Configure and verify the domain's DNS and inbound mail routing.
2. A Cloudflare Email Worker receives the message event and parses MIME content, subject to confirmed Cloudflare runtime and message limits.
3. Validate the envelope and message size; extract headers, supported body parts, and attachments.
4. Store attachment bytes in a private R2 bucket and normalized message data in Neon Postgres.
5. Make messages available through authenticated API endpoints.

Ordinary forwarding alone is not a durable inbox. Verify Cloudflare Email Workers' current message-handling constraints before relying on the design.

## Outbound email flow

1. An authenticated, authorized staff member composes a message in the frontend.
2. The server validates staff access, the school sender identity, recipients, subject, body, attachment references, and quotas.
3. The server sends through the Brevo API using a server-side secret.
4. Persist provider response IDs and status. Distinguish provider acceptance from confirmed delivery; verify signed delivery/bounce callbacks where supported.

Brevo suitability for a general-purpose shared inbox, sender policies, rate limits, and domain authentication remain unverified. If it cannot reliably support human correspondence, reassess the provider before implementing send workflows.

## Authentication and staff access

Authentication requirement is confirmed: Google sign-in and email/password. Neon Auth (managed Better Auth) is the current candidate, not a final integration commitment. Before enabling it, verify Neon project region/eligibility, network restrictions, Google OAuth app setup, trusted application origins, and production SMTP/custom sender setup. If managed auth is ineligible, select a supported alternative before implementing protected APIs.

- No public sign-up may automatically grant access to the school mailbox.
- Provision/approve staff separately from authentication; an authenticated identity is not automatically an authorized staff member.
- Use server-verified sessions/tokens and enforce mailbox access on every API request.
- Apply account verification, password reset, login throttling, and safe session handling.
- Google OAuth credentials and any auth/email secrets remain in provider/server configuration, never frontend source.

## Attachments

- Keep bytes in a private R2 bucket; do not expose public object URLs.
- Store object keys and metadata in Neon.
- Authorize every read/download and use short-lived signed access where appropriate.
- Enforce size and content policies. Never trust a supplied filename or MIME type.

## Planned components

- Web UI: React, Vite, TypeScript, Tailwind CSS, and shadcn/ui.
- API: Cloudflare Worker endpoints for auth/session verification, inbox queries, message actions, attachments, sending, and provider callbacks.
- Inbound handler: Cloudflare Email Worker entry point.
- Database: Neon Postgres with reviewed, versioned migrations.
- Object storage: private Cloudflare R2 bucket.
- Email provider: Brevo API for outbound sending and configured delivery/bounce callbacks.
- Notifications: FCM only after the core inbox flow is reliable.

## Shared mailbox behavior to settle

One logical school mailbox is shared among authorized staff. Individual staff identities must be recorded for audit attribution. Before implementing message-state mutations, decide whether read/unread status is shared globally or private per staff member, and define roles such as administrator, sender, and read-only staff.

## Initial data model proposal

Use staff identity mappings, one logical school mailbox, explicit staff-to-mailbox access/roles, messages, recipients, attachments, and audit events. Add provider event/idempotency records as required. Use foreign keys, indexes, timestamps, and unique constraints. Keep authentication-owned tables managed by the selected auth provider; do not duplicate password hashes or store provider secrets in ordinary application tables.

## Security requirements

- Implement authentication and staff authorization before exposing mailbox data.
- Enforce mailbox-level authorization on every query and attachment operation.
- Protect sign-in and send endpoints against brute force, CSRF where relevant, spam, and abuse.
- Keep credentials in server-side Cloudflare secrets/bindings only.
- Safely render untrusted HTML email; do not execute scripts or load remote images automatically by default.
- Validate MIME parsing, attachment size, file names, and content types.
- Rate-limit sending and impose recipient and attachment quotas.
- Do not log message bodies, credentials, tokens, or sensitive attachment data.
- Verify provider webhook signatures before applying delivery updates.
- Use TLS, restrictive CORS, secure cookies where applicable, and production-safe error responses.

## Configuration placeholders

- Server-side Neon connection configuration.
- Server-side Brevo API key.
- Private Cloudflare R2 bucket binding for attachments.
- Cloudflare Email Worker configuration and inbound domain routing.
- Auth provider configuration, trusted origins, and OAuth credentials.
- FCM credentials only if/when notifications are selected.

Use local `.dev.vars` only for local development and keep it ignored by Git. Production values belong in Cloudflare secrets and bindings. Never put secrets in `VITE_*` variables.

## Open decisions and verification

See [SECURITY-AND-OPEN-DECISIONS.md](SECURITY-AND-OPEN-DECISIONS.md) for the tracked list. No live email flow or production setup is considered verified until controlled end-to-end tests pass.
