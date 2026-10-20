-- Bukana Email Inbox: initial application schema.
-- Apply only to the dedicated Bukana project after review. Do not run against another project.
-- Authentication identities are owned by the configured provider; auth_subject stores the provider's stable subject.

CREATE TABLE mailboxes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE CHECK (email = lower(trim(email))),
  display_name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE staff_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_subject text NOT NULL UNIQUE,
  email text NOT NULL,
  display_name text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'active', 'suspended', 'deactivated')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX staff_members_email_lower_unique
  ON staff_members (lower(email));

CREATE TABLE mailbox_memberships (
  mailbox_id uuid NOT NULL REFERENCES mailboxes(id) ON DELETE RESTRICT,
  staff_member_id uuid NOT NULL REFERENCES staff_members(id) ON DELETE RESTRICT,
  role text NOT NULL CHECK (role IN ('administrator', 'sender', 'reader')),
  granted_by_staff_id uuid REFERENCES staff_members(id) ON DELETE SET NULL,
  granted_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  PRIMARY KEY (mailbox_id, staff_member_id)
);

CREATE INDEX mailbox_memberships_active_staff_idx
  ON mailbox_memberships (staff_member_id, mailbox_id)
  WHERE revoked_at IS NULL;

CREATE TABLE messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mailbox_id uuid NOT NULL REFERENCES mailboxes(id) ON DELETE RESTRICT,
  direction text NOT NULL CHECK (direction IN ('inbound', 'outbound')),
  status text NOT NULL CHECK (
    status IN ('received', 'draft', 'queued', 'provider_accepted', 'delivered', 'bounced', 'failed')
  ),
  sender_address text NOT NULL,
  reply_to_address text,
  subject text NOT NULL DEFAULT '',
  text_body text,
  html_body text,
  internet_message_id text,
  provider_name text,
  provider_message_id text,
  created_by_staff_id uuid REFERENCES staff_members(id) ON DELETE SET NULL,
  received_at timestamptz,
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX messages_mailbox_received_idx
  ON messages (mailbox_id, received_at DESC, created_at DESC);

CREATE INDEX messages_mailbox_status_idx
  ON messages (mailbox_id, status, created_at DESC);

CREATE UNIQUE INDEX messages_provider_id_unique
  ON messages (provider_name, provider_message_id)
  WHERE provider_name IS NOT NULL AND provider_message_id IS NOT NULL;

CREATE TABLE message_recipients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  recipient_type text NOT NULL CHECK (recipient_type IN ('to', 'cc', 'bcc')),
  address text NOT NULL,
  display_name text,
  delivery_status text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX message_recipients_message_idx ON message_recipients (message_id);
CREATE INDEX message_recipients_address_lower_idx ON message_recipients (lower(address));

CREATE TABLE attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  storage_key text NOT NULL UNIQUE,
  original_filename text NOT NULL,
  declared_content_type text,
  detected_content_type text,
  byte_size bigint NOT NULL CHECK (byte_size >= 0),
  sha256_hex text,
  content_id text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX attachments_message_idx ON attachments (message_id);

CREATE TABLE audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mailbox_id uuid REFERENCES mailboxes(id) ON DELETE RESTRICT,
  actor_staff_id uuid REFERENCES staff_members(id) ON DELETE SET NULL,
  action text NOT NULL,
  target_type text,
  target_id text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX audit_events_mailbox_time_idx
  ON audit_events (mailbox_id, created_at DESC);

CREATE TABLE provider_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_name text NOT NULL,
  external_event_id text NOT NULL,
  event_type text NOT NULL,
  payload_sha256_hex text,
  processing_status text NOT NULL DEFAULT 'pending'
    CHECK (processing_status IN ('pending', 'processing', 'processed', 'failed')),
  received_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  UNIQUE (provider_name, external_event_id)
);

INSERT INTO mailboxes (email, display_name)
VALUES ('info@bukanabriliantschools.com', 'Bukana Brilliant Schools')
ON CONFLICT (email) DO NOTHING;

-- Application code must enforce staff status, active membership, role permissions,
-- attachment authorization, and safe rendering. A valid auth session alone is not authorization.
-- Do not expose this database through a public/anonymous API.
