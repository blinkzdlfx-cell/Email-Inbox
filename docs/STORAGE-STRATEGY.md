# Storage Strategy and Provider Adapters

## 1. Decision summary

The platform will support four object-storage backends behind one application-level interface.

| Priority | Provider | Intended role | Published free storage allowance* |
|---|---|---|---:|
| Primary | Cloudflare R2 | Default production attachment store | 10 GB-month |
| Alternative | Backblaze B2 | Provider alternative / migration target | First 10 GB |
| Alternative | Tigris | Provider alternative / migration target | 5 GB Standard |
| Alternative | Supabase Storage | Convenient alternative for small deployments or specific use cases | 1 GB on Free |

*Allowances are subject to provider eligibility, account billing requirements, request limits, regional conditions, plan changes, and terms. They are not guaranteed capacity for our customers. Recheck official pricing before activation.

The four services are **not** four simultaneous copies of every file. One provider is authoritative for each stored object. Multi-provider replication or backup is a separate future capability requiring explicit design, cost analysis, and recovery testing.

## 2. Provider roles

### Cloudflare R2 — primary

Use R2 as the default attachment store.

- Private bucket; no public access by default.
- One Cloudflare account operated by the platform owner.
- One shared bucket per environment is the default (staging and production should be separate).
- Tenant-scoped opaque object keys.
- Server-side access through Cloudflare Workers and restricted credentials/bindings.
- Monitor storage, Class A and Class B operations, and account-level usage.
- R2 Standard free allowance currently lists 10 GB-month, 1 million Class A operations, 10 million Class B operations, and no internet egress fee.
- R2 activation may require a billing profile/payment method depending on account state. Do not assume the free allowance means no activation or billing setup is required.

### Backblaze B2 — alternative

- S3-compatible API; use an application key restricted to the required bucket and permissions.
- Keep the bucket private.
- First 10 GB of storage is currently advertised free; egress and transaction rules must be checked for the selected account and usage.
- The user previously encountered a registration obstacle. Treat B2 as a supported design target, not an available configured service until account creation and credentials are verified.

### Tigris — alternative

- S3-compatible object storage.
- Published free tier currently lists 5 GB Standard storage per month, 10,000 Class A requests, 100,000 Class B requests, and zero egress fees.
- Verify account eligibility, region/data residency, request allowances, and runtime compatibility before activation.

### Supabase Storage — alternative

- Integrates with the existing Supabase project and access-control ecosystem.
- Free plan currently lists 1 GB file storage and a 50 MB maximum file upload size.
- Do not assume Supabase Storage has the same capacity or economics as the database.
- Use only when its integration benefits justify the smaller allowance and project-level coupling.

## 3. Storage provider interface

Create an application-owned interface. Domain logic must not call vendor SDKs directly.

Suggested conceptual contract:

```ts
type ObjectRef = {
  provider: "r2" | "backblaze" | "tigris" | "supabase";
  container: string;
  key: string;
};

type StoredObject = {
  ref: ObjectRef;
  sizeBytes: number;
  contentType: string;
  checksum?: string;
  etag?: string;
};

interface StorageProvider {
  putObject(input: {
    key: string;
    body: ReadableStream | ArrayBuffer | Uint8Array;
    contentType: string;
    metadata?: Record<string, string>;
  }): Promise<StoredObject>;

  getObject(key: string): Promise<{
    body: ReadableStream;
    contentType?: string;
    sizeBytes?: number;
  }>;

  headObject(key: string): Promise<{
    sizeBytes: number;
    contentType?: string;
    checksum?: string;
    etag?: string;
  }>;

  deleteObject(key: string): Promise<void>;
}
```

This is a design contract, not an instruction to implement before the schema and integration plan are approved. Extend it only for provider capabilities actually needed and tested (multipart uploads, signed URLs, copy, versioning, checksums, etc.). Normalize errors without hiding whether a failure is retryable, permanent, or an authorization problem.

## 4. Object identity and database metadata

The `attachments` record should include:

- `id` — opaque application object ID.
- `tenant_id` — owning tenant.
- `message_id` — owning message, if attached to one.
- `storage_provider` — adapter identifier.
- `storage_container` — bucket/container name.
- `storage_key` — opaque object key.
- `original_filename` — untrusted display metadata, safely encoded on output.
- `content_type` — validated/detected media type where practical.
- `size_bytes` — actual stored size.
- `checksum` — integrity verification value where supported.
- `status` — pending, available, failed, deleting, deleted, or quarantined as appropriate.
- `created_at`, `deleted_at`, and relevant lifecycle timestamps.

Do not store provider secrets, permanent public URLs, or presigned URLs in the database. A temporary signed URL, if used, must be short-lived and generated only after authorization.

Object keys should be opaque and tenant-scoped, for example:

```text
tenants/{tenant_id}/attachments/{opaque_object_id}
```

Do not place original filenames or email addresses in object keys. Prefixes are for organization and operational convenience; they do not replace authorization.

## 5. Tenant quota accounting

Tenant quotas are logical limits over shared physical storage.

- Track actual object bytes by tenant.
- Account for pending uploads to prevent concurrent requests bypassing quota checks.
- Use transactional reservation/finalization or another race-safe accounting approach.
- Reconcile usage periodically against object metadata.
- Define whether trash/deleted-but-recoverable objects count against quota.
- Alert at configurable thresholds (80% and 95% are initial suggestions, not final product decisions).
- Enforce plan limits at upload time and provide clear UI feedback.

A tenant quota does not reserve physical capacity at the provider. Provider billing is based on aggregate account usage and request/transfer rules.

## 6. Upload and download lifecycle

### Upload

1. Authenticate the user and resolve active tenant membership.
2. Verify mailbox/message permission and tenant quota.
3. Validate declared size, then enforce actual streamed byte limits.
4. Validate content type and file signature where practical; scan/quarantine policy remains to be specified.
5. Generate an opaque object ID and storage key.
6. Write through the selected provider adapter.
7. Verify returned size/checksum/metadata as supported.
8. Persist attachment metadata and update usage accounting.
9. Mark the attachment available only after the object and metadata are consistent.

Define cleanup for partial uploads and orphaned objects.

### Download or preview

1. Authenticate and resolve tenant membership.
2. Load the attachment by ID from the database.
3. Verify tenant ownership and mailbox/message access.
4. Retrieve through the provider adapter or issue a short-lived signed URL only if the access pattern is safe.
5. Set safe content disposition and content-type headers.
6. Audit sensitive access without recording file contents.

Never accept an arbitrary bucket name, provider, or object key from the browser as authority to retrieve an object.

### Delete

1. Verify authorization.
2. Mark the object pending deletion or move it to a recoverable trash state according to retention policy.
3. Delete the object through the correct provider adapter when the grace period expires.
4. Update metadata and usage accounting idempotently.
5. Reconcile failures and orphaned objects through an operational job.

## 7. Provider migration

A provider migration must be an explicit controlled job:

1. Select a source object and target provider.
2. Read the source through its adapter.
3. Upload to the target with a new or equivalent opaque key.
4. Verify byte count and checksum where available.
5. Update the database reference transactionally after verification.
6. Keep the old object for a defined rollback grace period.
7. Delete the old object only after successful verification and the grace period.
8. Record the migration in audit/operational logs.

Do not automatically fall back to another provider after a failed upload unless the operation is idempotent and the authoritative reference is recorded. Do not delete the source before target verification.

## 8. Backup and replication

No multi-provider replication is selected for the first release. Provider alternatives are for deployment choice and migration flexibility, not a promise of automatic backup.

Before adding backup/replication, define:
- Recovery point and recovery time objectives.
- Whether message attachments require independent copies.
- Encryption and key management.
- Replication consistency and failure handling.
- Cost ownership and tenant disclosure.
- Restore drills and integrity verification.
- Deletion propagation and retention/legal-hold behavior.

A second provider is not a backup until restoration has been tested.

## 9. Retention policy

Do not silently remove email attachments after a fixed 30- or 90-day period. Initial policy should retain attachments until user deletion or an explicitly configured tenant retention rule applies.

Provide:
- Tenant-visible retention settings.
- Clear warnings before automated deletion.
- Trash/grace period and recovery where feasible.
- Optional administrative hold if required by the product's customer segment.
- A documented permanent-deletion process.
- Consistent deletion of object data and references.

Local downloads and browser caches are not the authoritative archive.

## 10. Operational requirements

Before production:
- Restrict credentials to required buckets and operations.
- Keep all credentials server-side.
- Test each adapter in the Cloudflare Workers runtime.
- Test large and interrupted uploads, retries, duplicate requests, and partial failures.
- Test cross-tenant access denial for upload, preview, download, and delete.
- Monitor provider storage and request usage.
- Configure alerts and a cost ceiling/budget process where available.
- Document how to rotate keys without losing access.
- Test restore/migration procedures before relying on them.

## 11. Official pricing references

Pricing changes. Recheck before implementation and periodically after launch.

- [Cloudflare R2 pricing](https://developers.cloudflare.com/r2/pricing/)
- [Backblaze B2 pricing](https://www.backblaze.com/cloud-storage/pricing)
- [Tigris pricing](https://www.tigrisdata.com/pricing/)
- [Supabase Storage pricing](https://supabase.com/docs/guides/storage/pricing)
