# Bukana Email Inbox — Architecture

## Goal
Build a reliable, secure email interface for Bukana Brilliant Schools with real inbound and outbound email. Keep provider credentials and privileged operations server-side.

## Inbound email flow
1. Configure the domain's MX/DNS records for Cloudflare Email Routing.
2. A Cloudflare Email Worker receives the message event and parses MIME content.
3. Validate the envelope and message size; extract headers, supported body parts, and attachments.
4. Store attachment bytes in a private R2 bucket and normalized message data in Neon Postgres.
5. Make messages available through authenticated API endpoints.

The exact Cloudflare receiving configuration and runtime limits must be verified. Ordinary forwarding alone is not a durable inbox.

## Outbound email flow
1. An authenticated user composes a message in the frontend.
2. The server validates sender identity, recipients, subject, body, attachment references, permissions, and quotas.
3. The server sends through the Brevo API using a server-side secret.
4. Persist the provider response and status. Distinguish provider acceptance from confirmed delivery; configure verified delivery/bounce webhooks if available.

## Attachments
- Keep bytes in a private R2 bucket; do not expose public object URLs.
- Store object keys and metadata in Neon.
- Authorize every read/download and use short-lived signed access where appropriate.
- Enforce size and content policies. Never trust a supplied filename or MIME type.

## Planned components
- Web UI: React, Vite, TypeScript, Tailwind CSS, and shadcn/ui.
- API: Cloudflare Worker endpoints for authentication, inbox queries, message actions, attachments, sending, and provider callbacks.
- Inbound handler: Cloudflare Email Worker entry point.
- Database: Neon Postgres with reviewed, versioned migrations.
- Object storage: private Cloudflare R2 bucket.
- Email provider: Brevo API for outbound sending and configured delivery/bounce callbacks.
- Notifications: FCM after the core inbox flow is reliable.

## Initial data model proposal
Finalize the schema after deciding authentication and mailbox ownership. Expected entities include users or identity records, mailboxes and access, messages, recipients, attachments, sessions/provider state, push subscriptions, and idempotent provider event records. Use foreign keys, indexes, timestamps, and unique constraints. Do not store provider secrets in ordinary application tables.

## Security requirements
- Implement authentication before exposing mailbox data.
- Enforce mailbox-level authorization on every query and attachment operation.
- Protect sign-in and send endpoints against brute force, CSRF where relevant, spam, and abuse.
- Keep credentials in server-side Cloudflare secrets/bindings only.
- Safely render untrusted HTML email; do not execute scripts or load remote images automatically by default.
- Validate MIME parsing, attachment size, file names, and content types.
- Rate-limit sending and impose recipient and attachment quotas.
- Do not log message bodies, credentials, tokens, or sensitive attachment data.
- Verify Brevo webhook signatures before applying delivery updates.
- Use TLS, restrictive CORS, secure cookies where applicable, and production-safe error responses.

## Configuration placeholders
- DATABASE_URL: server-side Neon connection string.
- BREVO_API_KEY: server-side Brevo API key.
- Cloudflare R2 bucket binding for attachments.
- Authentication/session secrets and allowed-origin configuration, selected after auth design.
- FCM credentials only if the selected integration requires them.

Use local .dev.vars only for local development and keep it ignored by Git. Production values belong in Cloudflare secrets and bindings. Public frontend variables must never contain secrets.

## Decisions to verify before implementation
- Domain name and mailbox naming strategy.
- Authentication and account provisioning method.
- One shared school mailbox versus individual staff mailboxes.
- Cloudflare inbound email parsing and attachment limits.
- Brevo sender/domain verification, DNS records, sending limits, and webhook setup.
- Neon connection strategy compatible with Cloudflare Workers.
- Hosting arrangement and exact Cloudflare bindings.
- Retention, deletion, backup, and audit requirements.