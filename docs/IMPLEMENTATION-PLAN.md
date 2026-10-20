# Implementation Plan

## Delivery principle
Prioritize a working end-to-end email loop, but do not skip security or claim an integration works until tested. The deadline does not override mailbox privacy, credential safety, or deliverability checks.

## Stage 0 — Repository and feasibility
- [x] Confirm repository and default branch.
- [x] Confirm repository was initially empty.
- [x] Record agreed stack and security constraints.
- [ ] Confirm domain control, DNS access, and mailbox/address model.
- [ ] Verify Cloudflare inbound Email Worker setup and Brevo sender/domain requirements.
- [ ] Select and document authentication/session approach.
- [ ] Confirm Neon and R2 resources and deployment bindings.

## Stage 1 — Secure application foundation
- [ ] Create frontend and Cloudflare-compatible API structure.
- [ ] Add environment validation and safe configuration examples.
- [ ] Establish schema migrations and mailbox ownership model.
- [ ] Implement authentication and authorization before mailbox endpoints.
- [ ] Add CI checks, formatting, type-checking, and tests.
Acceptance: clean install/build succeeds, no secrets are committed, and unauthenticated requests cannot read or mutate mailbox data.

## Stage 2 — Inbound email
- [ ] Implement Cloudflare email handler and MIME parsing.
- [ ] Store message metadata and body in Neon.
- [ ] Store attachments privately in R2.
- [ ] Make retries idempotent and handle malformed messages safely.
- [ ] Add authorized inbox listing and message detail endpoints.
Acceptance: a real test email to the configured domain appears in the authenticated inbox, including supported body parts and attachments, without cross-mailbox access.

## Stage 3 — Outbound email
- [ ] Implement compose, send, reply, and forward.
- [ ] Send through Brevo only from the server.
- [ ] Persist provider message IDs and clear status semantics.
- [ ] Validate recipients, attachment access, and sending limits.
- [ ] Configure and verify delivery/bounce webhooks where supported.
Acceptance: an authorized user sends a real message to an external test address; provider acceptance is not confused with final delivery.

## Stage 4 — User experience and notifications
- [ ] Build responsive inbox, message detail, sent mail, compose, reply, and forward views.
- [ ] Add search, loading/empty/error states, and safe HTML/plain-text rendering.
- [ ] Add FCM after the core email loop is reliable.
Acceptance: core flows work on desktop and mobile, with accessible controls and safe rendering.

## Stage 5 — Production verification
- [ ] Run unit, integration, and build checks.
- [ ] Test inbound and outbound mail using controlled addresses.
- [ ] Verify DNS, sender authentication, secrets, and production bindings.
- [ ] Test unauthorized access, malformed input, attachment limits, retries, and provider failures.
- [ ] Document deployment, operations, recovery, and known limitations.
Acceptance: deployment is reproducible and a test report distinguishes verified behavior from pending provider/domain setup.

## Immediate inputs needed
1. The domain that should receive school email and confirmation that its DNS can be changed.
2. Access to the relevant Cloudflare and Brevo accounts for configuration. Do not paste secret keys into chat or commit them.
3. Mailbox model: one shared school inbox or individual accounts for staff/users.

Zoho remains a fallback if Cloudflare/Brevo cannot provide reliable real-world receiving and sending within the delivery window.