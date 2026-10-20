# Bukana Email Inbox

A secure, school-managed email inbox for Bukana Brilliant Schools.

## Project status

The repository is being initialized. The first milestone is a verified architecture and deployment plan before application implementation.

## Planned stack

- Frontend: React, Vite, TypeScript, Tailwind CSS, and shadcn/ui
- Inbound email: Cloudflare Email Routing and an Email Worker
- Outbound email: Brevo transactional email API
- Database: Neon Postgres
- Attachments: Cloudflare R2
- Notifications: Firebase Cloud Messaging (FCM), subject to browser and permission support
- Hosting: Cloudflare Workers/Pages, with the exact deployment shape to be verified

## Security rules

- Keep Brevo API keys, database credentials, and other secrets on the server in platform secrets/environment bindings.
- Never expose credentials in frontend variables, committed files, logs, or API responses.
- Authenticate and authorize every mailbox operation on the server.
- Validate recipients, attachment size/type, message input, and upload/download access.
- Use parameterized SQL, rate limits, safe HTML rendering, and security-focused tests.
- Do not claim an email was delivered merely because the application accepted a send request.

## Core capabilities

The target workflow includes sign-in, inbox and message viewing, compose, reply, forward, sent mail, attachments, and notifications. These are requirements, not a claim that the features are implemented yet.

## Project documents

- Architecture: docs/ARCHITECTURE.md
- Implementation plan and acceptance checks: docs/IMPLEMENTATION-PLAN.md

## Important setup note

Email receiving and sending require control of the chosen domain's DNS and verification with Cloudflare and Brevo. Provider setup, credentials, mailbox/domain configuration, and production deliverability must be verified separately from local application tests.