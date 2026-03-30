-- Enhanced RLS Migration
-- Date: 2026-03-30
-- Purpose: Strengthen row-level security so that child tables (devices, documents,
--          maintenance_records, media, timeline_entries) verify both user_id AND
--          asset ownership. Also adds data-integrity constraints and soft-delete.

-- ============================================================================
-- 0. Soft-delete column on assets
-- ============================================================================

ALTER TABLE assets
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

COMMENT ON COLUMN assets.deleted_at IS 'Soft-delete timestamp. NULL = active.';

-- Index for efficient queries that exclude soft-deleted rows
CREATE INDEX IF NOT EXISTS idx_assets_deleted_at ON assets (deleted_at)
  WHERE deleted_at IS NULL;

-- ============================================================================
-- 1. File type validation constraint on documents
-- ============================================================================

ALTER TABLE documents
  DROP CONSTRAINT IF EXISTS documents_file_type_check;

ALTER TABLE documents
  ADD CONSTRAINT documents_file_type_check
  CHECK (file_type IS NULL OR file_type IN ('pdf', 'jpg', 'jpeg', 'png', 'webp'));

-- ============================================================================
-- 2. Metadata size constraint (prevent abuse via oversized JSONB payloads)
-- ============================================================================

-- Assets metadata: max 32 KB
ALTER TABLE assets
  DROP CONSTRAINT IF EXISTS assets_metadata_size_check;

ALTER TABLE assets
  ADD CONSTRAINT assets_metadata_size_check
  CHECK (octet_length(metadata::text) <= 32768);

-- Devices metadata: max 16 KB
ALTER TABLE devices
  DROP CONSTRAINT IF EXISTS devices_metadata_size_check;

ALTER TABLE devices
  ADD CONSTRAINT devices_metadata_size_check
  CHECK (octet_length(metadata::text) <= 16384);

-- Maintenance metadata: max 16 KB
ALTER TABLE maintenance_records
  DROP CONSTRAINT IF EXISTS maintenance_metadata_size_check;

ALTER TABLE maintenance_records
  ADD CONSTRAINT maintenance_metadata_size_check
  CHECK (octet_length(metadata::text) <= 16384);

-- Media metadata: max 8 KB
ALTER TABLE media
  DROP CONSTRAINT IF EXISTS media_metadata_size_check;

ALTER TABLE media
  ADD CONSTRAINT media_metadata_size_check
  CHECK (octet_length(metadata::text) <= 8192);

-- ============================================================================
-- 3. Helper function: verify that an asset belongs to the current user
-- ============================================================================

CREATE OR REPLACE FUNCTION public.user_owns_asset(p_asset_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.assets
    WHERE id = p_asset_id
      AND user_id = auth.uid()
      AND deleted_at IS NULL
  );
$$;

-- ============================================================================
-- 4. Enhanced RLS policies — ASSETS
-- ============================================================================

ALTER TABLE assets ENABLE ROW LEVEL SECURITY;

-- Drop legacy wide-open policies (if they exist)
DROP POLICY IF EXISTS "Users can CRUD own assets" ON assets;
DROP POLICY IF EXISTS "assets_select_own" ON assets;
DROP POLICY IF EXISTS "assets_insert_own" ON assets;
DROP POLICY IF EXISTS "assets_update_own" ON assets;
DROP POLICY IF EXISTS "assets_delete_own" ON assets;

-- SELECT: own non-deleted assets only
CREATE POLICY "assets_select_own" ON assets
  FOR SELECT
  USING (auth.uid() = user_id AND deleted_at IS NULL);

-- INSERT: user_id must match the authenticated user
CREATE POLICY "assets_insert_own" ON assets
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- UPDATE: only own assets
CREATE POLICY "assets_update_own" ON assets
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- DELETE: only own assets (prefer soft-delete in application code)
CREATE POLICY "assets_delete_own" ON assets
  FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- 5. Enhanced RLS policies — DEVICES
-- ============================================================================

ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can CRUD own devices" ON devices;
DROP POLICY IF EXISTS "devices_select_own" ON devices;
DROP POLICY IF EXISTS "devices_insert_own" ON devices;
DROP POLICY IF EXISTS "devices_update_own" ON devices;
DROP POLICY IF EXISTS "devices_delete_own" ON devices;

CREATE POLICY "devices_select_own" ON devices
  FOR SELECT
  USING (auth.uid() = user_id AND public.user_owns_asset(asset_id));

CREATE POLICY "devices_insert_own" ON devices
  FOR INSERT
  WITH CHECK (auth.uid() = user_id AND public.user_owns_asset(asset_id));

CREATE POLICY "devices_update_own" ON devices
  FOR UPDATE
  USING (auth.uid() = user_id AND public.user_owns_asset(asset_id))
  WITH CHECK (auth.uid() = user_id AND public.user_owns_asset(asset_id));

CREATE POLICY "devices_delete_own" ON devices
  FOR DELETE
  USING (auth.uid() = user_id AND public.user_owns_asset(asset_id));

-- ============================================================================
-- 6. Enhanced RLS policies — MAINTENANCE_RECORDS
-- ============================================================================

ALTER TABLE maintenance_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can CRUD own maintenance" ON maintenance_records;
DROP POLICY IF EXISTS "maintenance_select_own" ON maintenance_records;
DROP POLICY IF EXISTS "maintenance_insert_own" ON maintenance_records;
DROP POLICY IF EXISTS "maintenance_update_own" ON maintenance_records;
DROP POLICY IF EXISTS "maintenance_delete_own" ON maintenance_records;

CREATE POLICY "maintenance_select_own" ON maintenance_records
  FOR SELECT
  USING (auth.uid() = user_id AND public.user_owns_asset(asset_id));

CREATE POLICY "maintenance_insert_own" ON maintenance_records
  FOR INSERT
  WITH CHECK (auth.uid() = user_id AND public.user_owns_asset(asset_id));

CREATE POLICY "maintenance_update_own" ON maintenance_records
  FOR UPDATE
  USING (auth.uid() = user_id AND public.user_owns_asset(asset_id))
  WITH CHECK (auth.uid() = user_id AND public.user_owns_asset(asset_id));

CREATE POLICY "maintenance_delete_own" ON maintenance_records
  FOR DELETE
  USING (auth.uid() = user_id AND public.user_owns_asset(asset_id));

-- ============================================================================
-- 7. Enhanced RLS policies — DOCUMENTS
-- ============================================================================

ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can CRUD own documents" ON documents;
DROP POLICY IF EXISTS "documents_select_own" ON documents;
DROP POLICY IF EXISTS "documents_insert_own" ON documents;
DROP POLICY IF EXISTS "documents_update_own" ON documents;
DROP POLICY IF EXISTS "documents_delete_own" ON documents;

CREATE POLICY "documents_select_own" ON documents
  FOR SELECT
  USING (auth.uid() = user_id AND public.user_owns_asset(asset_id));

CREATE POLICY "documents_insert_own" ON documents
  FOR INSERT
  WITH CHECK (auth.uid() = user_id AND public.user_owns_asset(asset_id));

CREATE POLICY "documents_update_own" ON documents
  FOR UPDATE
  USING (auth.uid() = user_id AND public.user_owns_asset(asset_id))
  WITH CHECK (auth.uid() = user_id AND public.user_owns_asset(asset_id));

CREATE POLICY "documents_delete_own" ON documents
  FOR DELETE
  USING (auth.uid() = user_id AND public.user_owns_asset(asset_id));

-- ============================================================================
-- 8. Enhanced RLS policies — MEDIA
-- ============================================================================

ALTER TABLE media ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can CRUD own media" ON media;
DROP POLICY IF EXISTS "media_select_own" ON media;
DROP POLICY IF EXISTS "media_insert_own" ON media;
DROP POLICY IF EXISTS "media_update_own" ON media;
DROP POLICY IF EXISTS "media_delete_own" ON media;

CREATE POLICY "media_select_own" ON media
  FOR SELECT
  USING (auth.uid() = user_id AND public.user_owns_asset(asset_id));

CREATE POLICY "media_insert_own" ON media
  FOR INSERT
  WITH CHECK (auth.uid() = user_id AND public.user_owns_asset(asset_id));

CREATE POLICY "media_update_own" ON media
  FOR UPDATE
  USING (auth.uid() = user_id AND public.user_owns_asset(asset_id))
  WITH CHECK (auth.uid() = user_id AND public.user_owns_asset(asset_id));

CREATE POLICY "media_delete_own" ON media
  FOR DELETE
  USING (auth.uid() = user_id AND public.user_owns_asset(asset_id));

-- ============================================================================
-- 9. Enhanced RLS policies — TIMELINE_ENTRIES
-- ============================================================================

ALTER TABLE timeline_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can CRUD own timeline" ON timeline_entries;
DROP POLICY IF EXISTS "timeline_select_own" ON timeline_entries;
DROP POLICY IF EXISTS "timeline_insert_own" ON timeline_entries;
DROP POLICY IF EXISTS "timeline_update_own" ON timeline_entries;
DROP POLICY IF EXISTS "timeline_delete_own" ON timeline_entries;

CREATE POLICY "timeline_select_own" ON timeline_entries
  FOR SELECT
  USING (auth.uid() = user_id AND public.user_owns_asset(asset_id));

CREATE POLICY "timeline_insert_own" ON timeline_entries
  FOR INSERT
  WITH CHECK (auth.uid() = user_id AND public.user_owns_asset(asset_id));

CREATE POLICY "timeline_update_own" ON timeline_entries
  FOR UPDATE
  USING (auth.uid() = user_id AND public.user_owns_asset(asset_id))
  WITH CHECK (auth.uid() = user_id AND public.user_owns_asset(asset_id));

CREATE POLICY "timeline_delete_own" ON timeline_entries
  FOR DELETE
  USING (auth.uid() = user_id AND public.user_owns_asset(asset_id));

-- ============================================================================
-- 10. Indexes to support the new RLS function efficiently
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_assets_user_active
  ON assets (user_id, id)
  WHERE deleted_at IS NULL;
