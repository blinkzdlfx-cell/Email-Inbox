# Bukana Email Inbox

A secure, school-managed email inbox for Bukana Brilliant Schools.

## Confirmed decisions

- Shared mailbox: `info@bukanabriliantschools.com`
- School domain: `bukanabriliantschools.com`
- Staff sign-in: Supabase Auth with Google sign-in **and** email/password
- Database: Supabase Postgres
- Attachment storage: private Backblaze B2 bucket using its S3-compatible API
- Mailbox access: authorized staff accounts only; authentication alone does not grant school-mail access

## Planned stack

- Frontend: React, Vite, TypeScript, Tailwind CSS, and shadcn/ui
- API and application hosting: Cloudflare Workers
- Authentication and database: Supabase Auth and Supabase Postgres
- Attachments: Backblaze B2, private bucket accessed server-side through the Worker
- Inbound email: Cloudflare Email Routing and an Email Worker, subject to runtime and account verification
- Outbound email: Brevo API, subject to sender/domain verification and suitability for human correspondence

## Project status

The repository contains planning documentation and an initial application scaffold. Supabase project configuration, authentication flows, database provisioning/migration, Backblaze B2 integration, mail provider integrations, and production deployment are **not yet implemented or verified**. Do not treat the address above as proof that DNS, mail routing, or the mailbox is already configured.

## Security rules

- Keep Supabase secret/service-role keys, Backblaze B2 credentials, Brevo keys, OAuth secrets, and session secrets server-side.
- Never commit secrets or expose them through frontend variables, logs, or API responses.
- Authenticate users with Supabase Auth and separately authorize every mailbox operation on the server.
- Staff accounts must be explicitly approved; public sign-up must not grant mailbox access.
- Enable Row Level Security on application tables. Do not grant browser clients access to mailbox tables by default; access must be designed and tested before exposing any table through the Data API.
- Keep the Backblaze B2 bucket private. Authorize every upload/download through the Worker; never expose permanent public object URLs or credentials.
- Validate recipients, message input, attachment size/type, and upload/download permissions.
- Use parameterized SQL, rate limits, safe HTML rendering, and security-focused tests.
- Do not claim an email was delivered merely because a provider accepted a send request.

## Project documents

- [Architecture](docs/ARCHITECTURE.md)
- [Implementation plan](docs/IMPLEMENTATION-PLAN.md)
- [Security and unresolved decisions](docs/SECURITY-AND-OPEN-DECISIONS.md)

## Setup dependency

The domain owner must be able to configure DNS for Cloudflare and Brevo. A dedicated Supabase project, a private Backblaze B2 bucket, authentication provider settings, staff provisioning policy, and production bindings must be configured and tested separately from local application builds. Do not add real resource IDs or credentials to tracked files.
