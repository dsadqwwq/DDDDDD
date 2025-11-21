-- Create 10 new invite codes
-- Format: 4 uppercase letters + 4 numbers (e.g., ABCD1234)
-- These are system-generated codes (created_by = NULL)

INSERT INTO invite_codes (code, created_by, used_by, reserved_by, reserved_until, used_at) VALUES
  ('KQMX7492', NULL, NULL, NULL, NULL, NULL),
  ('HJPT3856', NULL, NULL, NULL, NULL, NULL),
  ('WNRS2107', NULL, NULL, NULL, NULL, NULL),
  ('ZLQF6438', NULL, NULL, NULL, NULL, NULL),
  ('VBGK9524', NULL, NULL, NULL, NULL, NULL),
  ('XCDW1763', NULL, NULL, NULL, NULL, NULL),
  ('MTNY4089', NULL, NULL, NULL, NULL, NULL),
  ('FSLP5621', NULL, NULL, NULL, NULL, NULL),
  ('DJHV8340', NULL, NULL, NULL, NULL, NULL),
  ('PGXR2957', NULL, NULL, NULL, NULL, NULL)
ON CONFLICT (code) DO NOTHING;

-- Show the newly created codes
SELECT
  code,
  created_at,
  CASE
    WHEN used_by IS NOT NULL THEN 'USED'
    WHEN reserved_by IS NOT NULL THEN 'RESERVED'
    ELSE 'AVAILABLE'
  END as status
FROM invite_codes
WHERE code IN (
  'KQMX7492', 'HJPT3856', 'WNRS2107', 'ZLQF6438', 'VBGK9524',
  'XCDW1763', 'MTNY4089', 'FSLP5621', 'DJHV8340', 'PGXR2957'
)
ORDER BY created_at DESC;

-- Show total available codes
SELECT COUNT(*) as total_available_codes
FROM invite_codes
WHERE used_by IS NULL
  AND (reserved_by IS NULL OR reserved_until < NOW());
