# Implementation Plan

## Delivery principle

Prioritize a working end-to-end email loop, but do not skip security or claim an integration works until tested. The deadline does not override mailbox privacy, credential safety, or deliverability checks.

## Stage 0 — Repository and feasibility

- [x] Confirm repository and default branch.
- [x] Confirm repository was initially empty.
- [x] Record agreed stack and security constraints.
- [x] Choose one shared school inbox for authorized staff.
- [x] Record domain `bukanabriliantschools.com` and address `info@bukanabriliantschools.com`.
- [x] Record both Google sign-in and email/password as staff authentication requirements.
- [ ] Verify domain ownership and DNS access.
- [ ] Verify Cloudflare inbound email configuration and runtime/message limits.
- [ ] Verify Brevo suitability for human correspondence, sender/domain authentication, limits, and callbacks.
- [ ] Verify Neon project eligibility for the selected auth approach and Cloudflare connection method.
- [ ] Confirm Cloudflare Pages/Workers and R2 resources/bindings.

## Stage 1 — Secure application foundation

- [x] Create React/Vite/TypeScript frontend and minimal Cloudflare-compatible API structure (sign-in intentionally disabled).
- [x] Add safe environment configuration example and secret-safe ignore rules.
- [ ] Choose and configure the authentication provider; support Google and email/password.
- [ ] Establish explicit staff provisioning/approval and server-side authorization.
- [x] Add an initial versioned schema migration for staff mapping, mailbox, messages, recipients, attachments, provider events, and audit records.
- [x] Add CI checks, type-checking, and an initial UI test. CI/build result still needs confirmation.
- Acceptance: clean install/build succeeds, no secrets are committed, and unauthenticated or unapproved requests cannot read or mutate mailbox data.

## Stage 2 — Inbound email

- [ ] Implement Cloudflare email handler and MIME parsing.
- [ ] Store message metadata and body in Neon.
- [ ] Store attachments privately in R2.
- [ ] Make retries idempotent and handle malformed messages safely.
- [ ] Add authorized inbox listing and message detail endpoints.
- Acceptance: a real test email to the configured domain appears in the authenticated inbox, including supported body parts and attachments, without cross-mailbox access.

## Stage 3 — Outbound email

- [ ] Implement compose, send, reply, and forward.
- [ ] Send through Brevo only from the server if provider feasibility is confirmed.
- [ ] Persist provider message IDs and clear status semantics.
- [ ] Validate recipients, attachment access, and sending limits.
- [ ] Configure and verify delivery/bounce webhooks where supported.
- Acceptance: an authorized user sends a real message to an external test address; provider acceptance is not confused with final delivery.

## Stage 4 — User experience and notifications

- [ ] Build responsive inbox, message detail, sent mail, compose, reply, and forward views.
- [ ] Add search, loading/empty/error states, and safe HTML/plain-text rendering.
- [ ] Add FCM after the core email loop is reliable.
- Acceptance: core flows work on desktop and mobile, with accessible controls and safe rendering.

## Stage 5 — Production verification

- [ ] Run unit, integration, and build checks.
- [ ] Test inbound and outbound mail using controlled addresses.
- [ ] Verify DNS, sender authentication, secrets, and production bindings.
- [ ] Test unauthorized access, malformed input, attachment limits, retries, and provider failures.
- [ ] Document deployment, operations, recovery, and known limitations.
- Acceptance: deployment is reproducible and a test report distinguishes verified behavior from pending provider/domain setup.

See [SECURITY-AND-OPEN-DECISIONS.md](SECURITY-AND-OPEN-DECISIONS.md) for the current decision register. Do not paste secret keys into chat or commit them. Zoho remains a fallback only if Cloudflare/Brevo cannot provide reliable real-world receiving and sending within the delivery window.
