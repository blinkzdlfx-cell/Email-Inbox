# Bukana Email Inbox

A secure, school-managed email inbox for Bukana Brilliant Schools.

## Confirmed decisions

- Shared mailbox: `info@bukanabriliantschools.com`
- School domain: `bukanabriliantschools.com`
- Staff sign-in: Google sign-in **and** email/password
- Mailbox access: authorized staff accounts only; no public self-service access to school mail

## Planned stack

- Frontend: React, Vite, TypeScript, Tailwind CSS, and shadcn/ui
- API and application hosting: Cloudflare Workers
- Database: Cloudflare D1 (SQLite)
- Attachment storage: Backblaze B2 using its S3-compatible API; private bucket only
- Inbound email: Cloudflare Email Routing and an Email Worker, subject to runtime and account verification
- Outbound email: Brevo API, subject to sender/domain verification and suitability for human correspondence
- Authentication: provider not yet selected or configured; must support Google sign-in and email/password

## Project status

The repository contains planning documentation and an initial application scaffold. Authentication, D1 provisioning/binding, Backblaze B2 integration, provider integrations, and production deployment are **not yet implemented or verified**. Do not treat the address above as proof that DNS, mail routing, or the mailbox is already configured.

## Security rules

- Keep provider keys, database credentials, OAuth secrets, and session secrets server-side.
- Never commit secrets or expose them through frontend variables, logs, or API responses.
- Authenticate and authorize every mailbox operation on the server.
- Staff accounts must be explicitly approved; public sign-up must not grant mailbox access.
- Keep the Backblaze B2 bucket private. Authorize every upload/download through the Worker; never expose permanent public object URLs or credentials.
- Validate recipients, message input, attachment size/type, and upload/download permissions.
- Use parameterized SQL, rate limits, safe HTML rendering, and security-focused tests.
- Do not claim an email was delivered merely because a provider accepted a send request.

## Project documents

- [Architecture](docs/ARCHITECTURE.md)
- [Implementation plan](docs/IMPLEMENTATION-PLAN.md)
- [Security and unresolved decisions](docs/SECURITY-AND-OPEN-DECISIONS.md)

## Setup dependency

The domain owner must be able to configure DNS for Cloudflare and Brevo. Cloudflare D1 and Backblaze B2 resources, credentials, staff provisioning policy, and production bindings must be configured and tested separately from local application builds. Do not add real resource IDs or credentials to tracked files.
