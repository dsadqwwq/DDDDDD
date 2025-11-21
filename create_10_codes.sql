-- Create 10 new invite codes
-- Format: 4 uppercase letters + 4 numbers
-- These are system-generated codes (created_by = NULL)

INSERT INTO invite_codes (code, created_by, used_by, reserved_by, reserved_until, used_at) VALUES
  ('FIRE2025', NULL, NULL, NULL, NULL, NULL),
  ('BLAZ3456', NULL, NULL, NULL, NULL, NULL),
  ('FURY7890', NULL, NULL, NULL, NULL, NULL),
  ('RAGE1122', NULL, NULL, NULL, NULL, NULL),
  ('DUEL3344', NULL, NULL, NULL, NULL, NULL),
  ('EPIC5566', NULL, NULL, NULL, NULL, NULL),
  ('WINN7788', NULL, NULL, NULL, NULL, NULL),
  ('HERO9900', NULL, NULL, NULL, NULL, NULL),
  ('GOLD1357', NULL, NULL, NULL, NULL, NULL),
  ('STAR2468', NULL, NULL, NULL, NULL, NULL)
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
  'FIRE2025', 'BLAZ3456', 'FURY7890', 'RAGE1122', 'DUEL3344',
  'EPIC5566', 'WINN7788', 'HERO9900', 'GOLD1357', 'STAR2468'
)
ORDER BY created_at DESC;

-- Show total available codes
SELECT COUNT(*) as total_available_codes
FROM invite_codes
WHERE used_by IS NULL
  AND (reserved_by IS NULL OR reserved_until < NOW());
