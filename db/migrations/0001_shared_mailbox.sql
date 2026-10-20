-- Bukana Email Inbox: initial Supabase Postgres schema.
-- Apply only to the dedicated Bukana Supabase project after review.
-- Supabase Auth owns auth.users and credentials. This schema stores the stable auth user ID.
-- This replaces the un-applied D1/SQLite draft; it is not SQLite-compatible.

CREATE TABLE IF NOT EXISTS public.mailboxes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE CHECK (email = lower(trim(email))),
  display_name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.staff_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE RESTRICT,
  email text NOT NULL,
  display_name text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'active', 'suspended', 'deactivated')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS staff_members_email_lower_unique
  ON public.staff_members (lower(email));

CREATE TABLE IF NOT EXISTS public.mailbox_memberships (
  mailbox_id uuid NOT NULL REFERENCES public.mailboxes(id) ON DELETE RESTRICT,
  staff_member_id uuid NOT NULL REFERENCES public.staff_members(id) ON DELETE RESTRICT,
  role text NOT NULL CHECK (role IN ('administrator', 'sender', 'reader')),
  granted_by_staff_id uuid REFERENCES public.staff_members(id) ON DELETE SET NULL,
  granted_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  PRIMARY KEY (mailbox_id, staff_member_id)
);

CREATE INDEX IF NOT EXISTS mailbox_memberships_active_staff_idx
  ON public.mailbox_memberships (staff_member_id, mailbox_id)
  WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mailbox_id uuid NOT NULL REFERENCES public.mailboxes(id) ON DELETE RESTRICT,
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
  created_by_staff_id uuid REFERENCES public.staff_members(id) ON DELETE SET NULL,
  received_at timestamptz,
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS messages_mailbox_received_idx
  ON public.messages (mailbox_id, received_at DESC, created_at DESC);

CREATE INDEX IF NOT EXISTS messages_mailbox_status_idx
  ON public.messages (mailbox_id, status, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS messages_provider_id_unique
  ON public.messages (provider_name, provider_message_id)
  WHERE provider_name IS NOT NULL AND provider_message_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.message_recipients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  recipient_type text NOT NULL CHECK (recipient_type IN ('to', 'cc', 'bcc')),
  address text NOT NULL,
  display_name text,
  delivery_status text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS message_recipients_message_idx
  ON public.message_recipients (message_id);

CREATE INDEX IF NOT EXISTS message_recipients_address_lower_idx
  ON public.message_recipients (lower(address));

CREATE TABLE IF NOT EXISTS public.attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  storage_key text NOT NULL UNIQUE,
  original_filename text NOT NULL,
  declared_content_type text,
  detected_content_type text,
  byte_size bigint NOT NULL CHECK (byte_size >= 0),
  sha256_hex text,
  content_id text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS attachments_message_idx
  ON public.attachments (message_id);

CREATE TABLE IF NOT EXISTS public.audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mailbox_id uuid REFERENCES public.mailboxes(id) ON DELETE RESTRICT,
  actor_staff_id uuid REFERENCES public.staff_members(id) ON DELETE SET NULL,
  action text NOT NULL,
  target_type text,
  target_id text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS audit_events_mailbox_time_idx
  ON public.audit_events (mailbox_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.provider_events (
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

-- Enable RLS on every application table. No browser-facing policies are defined here:
-- all mailbox access must be added deliberately after a policy review. The Worker must
-- verify Supabase Auth and enforce staff approval, active membership, and role permissions.
ALTER TABLE public.mailboxes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mailbox_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_events ENABLE ROW LEVEL SECURITY;

INSERT INTO public.mailboxes (email, display_name)
VALUES ('info@bukanabriliantschools.com', 'Bukana Brilliant Schools')
ON CONFLICT (email) DO NOTHING;

-- Do not grant direct browser access to mailbox data by default.
-- Never expose a service-role/secret key in frontend code.
