-- NUCLEAR OPTION: Complete database reset
-- Run this ENTIRE script in Supabase SQL Editor

-- 1. DROP EVERYTHING
DROP TRIGGER IF EXISTS generate_user_code_on_generation ON users CASCADE;
DROP TRIGGER IF EXISTS on_user_created ON users CASCADE;
DROP TRIGGER IF EXISTS after_user_insert ON users CASCADE;
DROP TRIGGER IF EXISTS create_codes_for_user ON users CASCADE;

DROP FUNCTION IF EXISTS create_user_codes(uuid) CASCADE;
DROP FUNCTION IF EXISTS generate_user_codes() CASCADE;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;

DROP TABLE IF EXISTS codes CASCADE;
DROP TABLE IF EXISTS scores CASCADE;
DROP TABLE IF EXISTS quests CASCADE;
DROP TABLE IF EXISTS inventory CASCADE;
DROP TABLE IF EXISTS wallet_connections CASCADE;
DROP TABLE IF EXISTS game_sessions CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- 2. CREATE USERS TABLE
CREATE TABLE users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  display_name text unique not null,
  points integer default 0,
  wallet_address text,
  level integer default 1,
  total_wins integer default 0,
  win_streak integer default 0,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- 3. CREATE CODES TABLE
CREATE TABLE codes (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  created_by uuid references users(id) on delete set null,
  used_by uuid references users(id) on delete set null,
  used_at timestamp with time zone,
  created_at timestamp with time zone default now()
);

-- 4. CREATE SCORES TABLE
CREATE TABLE scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade not null,
  time_ms integer not null,
  game_type text default 'reaction',
  created_at timestamp with time zone default now()
);

-- 5. CREATE QUESTS TABLE
CREATE TABLE quests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade not null,
  quest_id text not null,
  progress integer default 0,
  completed_at timestamp with time zone,
  claimed_at timestamp with time zone,
  start_time timestamp with time zone,
  reset_date date default current_date,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  unique(user_id, quest_id, reset_date)
);

-- 6. ENABLE RLS ON ALL TABLES
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE quests ENABLE ROW LEVEL SECURITY;

-- 7. CREATE PERMISSIVE POLICIES
CREATE POLICY "Allow all" ON users FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON codes FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON scores FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON quests FOR ALL USING (true) WITH CHECK (true);

-- 8. CREATE create_user_codes FUNCTION (NO TRIGGER - called manually by app)
CREATE FUNCTION create_user_codes(user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY definer
AS $$
DECLARE
  i integer;
  new_code text;
  code_exists boolean;
BEGIN
  FOR i IN 1..3 LOOP
    LOOP
      new_code := upper(substring(md5(random()::text) from 1 for 8));
      SELECT exists(SELECT 1 FROM codes WHERE code = new_code) INTO code_exists;
      IF NOT code_exists THEN
        INSERT INTO codes (code, created_by) VALUES (new_code, user_id);
        EXIT;
      END IF;
    END LOOP;
  END LOOP;
END;
$$;

-- 9. CREATE OTHER RPC FUNCTIONS
CREATE FUNCTION get_leaderboard(time_filter text default 'all', limit_count integer default 100)
RETURNS table (
  rank bigint,
  user_id uuid,
  display_name text,
  email text,
  time_ms integer,
  created_at timestamp with time zone
)
LANGUAGE plpgsql
AS $$
DECLARE filter_date timestamp with time zone;
BEGIN
  CASE time_filter
    WHEN 'today' THEN filter_date := current_date;
    WHEN 'week' THEN filter_date := current_date - interval '7 days';
    WHEN 'month' THEN filter_date := date_trunc('month', current_date);
    ELSE filter_date := '1970-01-01'::timestamp;
  END CASE;

  RETURN QUERY
  SELECT
    row_number() over (order by s.time_ms asc) as rank,
    s.user_id, u.display_name, u.email, s.time_ms, s.created_at
  FROM (
    SELECT user_id, min(time_ms) as time_ms, max(created_at) as created_at
    FROM scores WHERE created_at >= filter_date GROUP BY user_id
  ) s
  JOIN users u ON u.id = s.user_id
  ORDER BY s.time_ms ASC LIMIT limit_count;
END;
$$;

CREATE FUNCTION update_quest_progress(p_user_id uuid, p_quest_id text, p_increment integer default 1)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO quests (user_id, quest_id, progress, reset_date)
  VALUES (p_user_id, p_quest_id, p_increment, current_date)
  ON CONFLICT (user_id, quest_id, reset_date)
  DO UPDATE SET progress = quests.progress + p_increment, updated_at = now();
END;
$$;

CREATE FUNCTION claim_quest_reward(p_user_id uuid, p_quest_id text, p_reward_points integer)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE quest_completed boolean;
BEGIN
  SELECT (progress >= 1 and claimed_at is null) INTO quest_completed
  FROM quests WHERE user_id = p_user_id AND quest_id = p_quest_id AND reset_date = current_date;

  IF quest_completed THEN
    UPDATE quests SET claimed_at = now() WHERE user_id = p_user_id AND quest_id = p_quest_id AND reset_date = current_date;
    UPDATE users SET points = points + p_reward_points WHERE id = p_user_id;
    RETURN true;
  ELSE
    RETURN false;
  END IF;
END;
$$;

-- 10. INSERT 20 TEST CODES
INSERT INTO codes (code) VALUES
  ('TEST1234'), ('TEST5678'), ('DEMO1234'), ('DEMO5678'),
  ('ALPHA001'), ('ALPHA002'), ('BETA0001'), ('BETA0002'),
  ('GAMMA123'), ('DELTA456'), ('START001'), ('START002'),
  ('INVITE01'), ('INVITE02'), ('ACCESS01'), ('ACCESS02'),
  ('WELCOME1'), ('WELCOME2'), ('DUELPVP1'), ('DUELPVP2');

-- 11. VERIFY EVERYTHING
SELECT
  (SELECT COUNT(*) FROM users) as total_users,
  (SELECT COUNT(*) FROM codes WHERE used_by IS NULL) as available_codes,
  (SELECT COUNT(*) FROM information_schema.triggers WHERE event_object_table = 'users') as user_triggers,
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'create_user_codes') as has_function;

-- Should show: total_users: 0, available_codes: 20, user_triggers: 0, has_function: 1
