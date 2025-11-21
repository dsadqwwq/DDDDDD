-- Create 10 new invite codes
-- Format: 4 uppercase letters + 4 numbers (e.g., ABCD1234)
-- These are system-generated codes (created_by = NULL)

INSERT INTO invite_codes (code, created_by, used_by, reserved_by, reserved_until, used_at) VALUES
  ('QWER1234', NULL, NULL, NULL, NULL, NULL),
  ('ASDF5678', NULL, NULL, NULL, NULL, NULL),
  ('ZXCV9012', NULL, NULL, NULL, NULL, NULL),
  ('TYUI3456', NULL, NULL, NULL, NULL, NULL),
  ('GHJK7890', NULL, NULL, NULL, NULL, NULL),
  ('BNMA2345', NULL, NULL, NULL, NULL, NULL),
  ('PLOK6789', NULL, NULL, NULL, NULL, NULL),
  ('WERT0123', NULL, NULL, NULL, NULL, NULL),
  ('SDFG4567', NULL, NULL, NULL, NULL, NULL),
  ('XCVB8901', NULL, NULL, NULL, NULL, NULL)
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
  'QWER1234', 'ASDF5678', 'ZXCV9012', 'TYUI3456', 'GHJK7890',
  'BNMA2345', 'PLOK6789', 'WERT0123', 'SDFG4567', 'XCVB8901'
)
ORDER BY created_at DESC;

-- Show total available codes
SELECT COUNT(*) as total_available_codes
FROM invite_codes
WHERE used_by IS NULL
  AND (reserved_by IS NULL OR reserved_until < NOW());
