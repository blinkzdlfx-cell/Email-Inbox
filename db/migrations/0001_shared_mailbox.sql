-- Bukana Email Inbox: initial Cloudflare D1 / SQLite schema.
-- Apply only to the dedicated Bukana D1 database after review.
-- This file replaces the earlier un-applied PostgreSQL draft; it is not PostgreSQL-compatible.
-- Generate UUID strings in application code. Authentication identities belong to the chosen auth provider.


CREATE TABLE IF NOT EXISTS mailboxes (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE CHECK (email = lower(trim(email))),
  display_name TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS staff_members (
  id TEXT PRIMARY KEY,
  auth_subject TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL,
  display_name TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'active', 'suspended', 'deactivated')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS staff_members_email_lower_unique
  ON staff_members (lower(email));

CREATE TABLE IF NOT EXISTS mailbox_memberships (
  mailbox_id TEXT NOT NULL REFERENCES mailboxes(id) ON DELETE RESTRICT,
  staff_member_id TEXT NOT NULL REFERENCES staff_members(id) ON DELETE RESTRICT,
  role TEXT NOT NULL CHECK (role IN ('administrator', 'sender', 'reader')),
  granted_by_staff_id TEXT REFERENCES staff_members(id) ON DELETE SET NULL,
  granted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  revoked_at TEXT,
  PRIMARY KEY (mailbox_id, staff_member_id)
);

CREATE INDEX IF NOT EXISTS mailbox_memberships_active_staff_idx
  ON mailbox_memberships (staff_member_id, mailbox_id)
  WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY,
  mailbox_id TEXT NOT NULL REFERENCES mailboxes(id) ON DELETE RESTRICT,
  direction TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')),
  status TEXT NOT NULL CHECK (
    status IN ('received', 'draft', 'queued', 'provider_accepted', 'delivered', 'bounced', 'failed')
  ),
  sender_address TEXT NOT NULL,
  reply_to_address TEXT,
  subject TEXT NOT NULL DEFAULT '',
  text_body TEXT,
  html_body TEXT,
  internet_message_id TEXT,
  provider_name TEXT,
  provider_message_id TEXT,
  created_by_staff_id TEXT REFERENCES staff_members(id) ON DELETE SET NULL,
  received_at TEXT,
  sent_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS messages_mailbox_received_idx
  ON messages (mailbox_id, received_at DESC, created_at DESC);

CREATE INDEX IF NOT EXISTS messages_mailbox_status_idx
  ON messages (mailbox_id, status, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS messages_provider_id_unique
  ON messages (provider_name, provider_message_id)
  WHERE provider_name IS NOT NULL AND provider_message_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS message_recipients (
  id TEXT PRIMARY KEY,
  message_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  recipient_type TEXT NOT NULL CHECK (recipient_type IN ('to', 'cc', 'bcc')),
  address TEXT NOT NULL,
  display_name TEXT,
  delivery_status TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS message_recipients_message_idx
  ON message_recipients (message_id);

CREATE INDEX IF NOT EXISTS message_recipients_address_lower_idx
  ON message_recipients (lower(address));

CREATE TABLE IF NOT EXISTS attachments (
  id TEXT PRIMARY KEY,
  message_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  storage_key TEXT NOT NULL UNIQUE,
  original_filename TEXT NOT NULL,
  declared_content_type TEXT,
  detected_content_type TEXT,
  byte_size INTEGER NOT NULL CHECK (byte_size >= 0),
  sha256_hex TEXT,
  content_id TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS attachments_message_idx
  ON attachments (message_id);

CREATE TABLE IF NOT EXISTS audit_events (
  id TEXT PRIMARY KEY,
  mailbox_id TEXT REFERENCES mailboxes(id) ON DELETE RESTRICT,
  actor_staff_id TEXT REFERENCES staff_members(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  target_type TEXT,
  target_id TEXT,
  metadata_json TEXT NOT NULL DEFAULT '{}'
    CHECK (json_valid(metadata_json)),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS audit_events_mailbox_time_idx
  ON audit_events (mailbox_id, created_at DESC);

CREATE TABLE IF NOT EXISTS provider_events (
  id TEXT PRIMARY KEY,
  provider_name TEXT NOT NULL,
  external_event_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  payload_sha256_hex TEXT,
  processing_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (processing_status IN ('pending', 'processing', 'processed', 'failed')),
  received_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  processed_at TEXT,
  UNIQUE (provider_name, external_event_id)
);

INSERT INTO mailboxes (id, email, display_name)
VALUES ('bukana-shared-mailbox', 'info@bukanabriliantschools.com', 'Bukana Brilliant Schools')
ON CONFLICT (email) DO NOTHING;

-- Application code must enforce staff status, active membership, role permissions,
-- attachment authorization, and safe rendering. A valid auth session alone is not authorization.
-- Do not expose this database through a public/anonymous API.
