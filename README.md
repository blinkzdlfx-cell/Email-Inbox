# Bukana Email Inbox

A secure, school-managed email inbox for Bukana Brilliant Schools.

## Confirmed decisions

- Shared mailbox: `info@bukanabriliantschools.com`
- School domain: `bukanabriliantschools.com`
- Staff sign-in: Google sign-in **and** email/password
- Mailbox access: authorized staff accounts only; no public self-service access to school mail

## Planned stack

- Frontend: React, Vite, TypeScript, Tailwind CSS, and shadcn/ui
- Inbound email: Cloudflare Email Routing and an Email Worker, subject to runtime and account verification
- Outbound email: Brevo API, subject to sender/domain verification and suitability for human correspondence
- Database: Neon Postgres
- Attachments: private Cloudflare R2 bucket
- Authentication candidate: Neon Auth (managed Better Auth), pending confirmation that the Neon project is eligible and the required production configuration is available
- Hosting: Cloudflare Workers/Pages; exact deployment shape to be verified

## Project status

The repository currently contains planning documentation. Application code, authentication, database migrations, provider integrations, and deployment are **not yet implemented or verified**. Do not treat the address above as proof that DNS, mail routing, or the mailbox is already configured.

## Security rules

- Keep provider keys, database credentials, OAuth secrets, and session secrets server-side.
- Never commit secrets or expose them through frontend variables, logs, or API responses.
- Authenticate and authorize every mailbox operation on the server.
- Staff accounts must be explicitly approved; public sign-up must not grant mailbox access.
- Validate recipients, message input, attachment size/type, and upload/download permissions.
- Use parameterized SQL, rate limits, safe HTML rendering, and security-focused tests.
- Do not claim an email was delivered merely because a provider accepted a send request.

## Project documents

- [Architecture](docs/ARCHITECTURE.md)
- [Implementation plan](docs/IMPLEMENTATION-PLAN.md)
- [Security and unresolved decisions](docs/SECURITY-AND-OPEN-DECISIONS.md)

## Setup dependency

The domain owner must be able to configure DNS for Cloudflare and Brevo. Provider credentials, Neon/R2 resources, staff provisioning policy, and production bindings must be configured and tested separately from local application builds.
