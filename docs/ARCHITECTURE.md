# Bukana Email Inbox — Architecture

## Goal and confirmed configuration

Build a reliable, secure email interface for Bukana Brilliant Schools.

- Domain: `bukanabriliantschools.com`
- Shared mailbox: `info@bukanabriliantschools.com`
- Mailbox model: one shared school inbox for authorized staff
- Authentication requirement: both Google sign-in and email/password
- Database: Cloudflare D1
- Attachment storage: Backblaze B2, accessed through its S3-compatible API

These are application decisions, not proof that DNS, provider accounts, or the mailbox have been configured.

## Inbound email flow

1. Configure and verify the domain's DNS and inbound mail routing.
2. A Cloudflare Email Worker receives the message event and parses MIME content, subject to confirmed Cloudflare runtime and message limits.
3. Validate the envelope and message size; extract headers, supported body parts, and attachments.
4. Store attachment bytes in a private Backblaze B2 bucket and normalized message data in Cloudflare D1.
5. Make messages available through authenticated API endpoints.

Ordinary forwarding alone is not a durable inbox. Verify Cloudflare Email Workers' current message-handling constraints before relying on the design. Handle duplicate deliveries idempotently.

## Outbound email flow

1. An authenticated, authorized staff member composes a message in the frontend.
2. The server validates staff access, the school sender identity, recipients, subject, body, attachment references, and quotas.
3. The server sends through the Brevo API using a server-side secret.
4. Persist provider response IDs and status. Distinguish provider acceptance from confirmed delivery; verify signed delivery/bounce callbacks where supported.

Brevo suitability for a general-purpose shared inbox, sender policies, rate limits, and domain authentication remain unverified. If it cannot reliably support human correspondence, reassess the provider before implementing send workflows.

## Authentication and staff access

Authentication must support Google sign-in and email/password. The provider has not been selected or verified; do not assume a D1 database provides authentication.

- No public sign-up may automatically grant access to the school mailbox.
- Provision/approve staff separately from authentication; an authenticated identity is not automatically an authorized staff member.
- Use server-verified sessions/tokens and enforce mailbox access on every API request.
- Apply account verification, password reset, login throttling, and safe session handling.
- Google OAuth credentials and any auth/email secrets remain in provider/server configuration, never frontend source.
- Do not implement custom password/session cryptography. Select a maintained authentication solution before protected endpoints are built.

## Database: Cloudflare D1

D1 is the source of truth for structured application data:

- Staff identity mapping, approval status, and mailbox roles.
- Message headers, normalized recipients, plain-text/HTML bodies, provider IDs, and status.
- Attachment metadata and private Backblaze B2 object keys.
- Audit events and idempotent provider webhook events.

Use versioned SQLite-compatible migrations, parameterized queries, indexes, foreign keys, and uniqueness constraints. Generate UUIDs in application code and store them as TEXT. Keep authentication-owned tables managed by the selected auth provider; do not store plaintext passwords or duplicate password hashes.

Do not configure a D1 binding until the dedicated database is created and its actual database ID is known. Never point this project at an unrelated production database.

## Attachment storage: Backblaze B2

- Create a dedicated private bucket for Bukana attachments.
- Use an application key restricted to that bucket and only the permissions required by the app.
- Store object keys and metadata in D1; do not store attachment bytes in D1.
- Access B2 through the Worker using the S3-compatible API and server-side credentials.
- Authorize every upload, preview, and download against the current staff identity and mailbox membership.
- Never expose B2 application keys to the browser or publish permanent public object URLs.
- Validate actual content where practical, impose size/type limits, generate opaque object keys, and treat original filenames as untrusted.
- Define deletion and retention behavior for objects when messages or attachments are removed.
- Test the selected S3-compatible client/signing approach in the Cloudflare Workers runtime before relying on it in production.

## Planned components

- Web UI: React, Vite, TypeScript, Tailwind CSS, and shadcn/ui.
- API: Cloudflare Worker endpoints for auth/session verification, inbox queries, message actions, attachments, sending, and provider callbacks.
- Inbound handler: Cloudflare Email Worker entry point.
- Database: Cloudflare D1 with reviewed, versioned SQLite migrations.
- Object storage: private Backblaze B2 bucket through the S3-compatible API.
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

- Cloudflare D1 binding and actual database ID after provisioning.
- Backblaze B2 bucket name, S3-compatible endpoint/region, key ID, and application key as server-side secrets/configuration.
- Server-side Brevo API key.
- Cloudflare Email Worker configuration and inbound domain routing.
- Auth provider configuration, trusted origins, and OAuth credentials.
- FCM credentials only if/when notifications are selected.

Use local `.dev.vars` only for local development and keep it ignored by Git. Production values belong in Cloudflare secrets and bindings. Never put secrets in `VITE_*` variables.

## Open decisions and verification

See [SECURITY-AND-OPEN-DECISIONS.md](SECURITY-AND-OPEN-DECISIONS.md) for the tracked list. No live email flow or production setup is considered verified until controlled end-to-end tests pass.
