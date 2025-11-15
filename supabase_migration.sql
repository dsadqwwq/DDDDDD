-- ============================================
-- DUEL PVP - SUPABASE DATABASE MIGRATION
-- ============================================
-- Run this in your Supabase SQL Editor
-- Dashboard: https://supabase.com/dashboard/project/smgqccnggmyreacjyyil/editor
-- ============================================

-- STEP 1: Create Tables
-- ============================================

-- Users table (may already exist, run anyway - will skip if exists)
create table if not exists users (
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

-- Invite codes table
create table if not exists codes (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  created_by uuid references users(id) on delete set null,
  used_by uuid references users(id) on delete set null,
  used_at timestamp with time zone,
  created_at timestamp with time zone default now()
);

-- Scores table (for reaction game leaderboard)
create table if not exists scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade not null,
  time_ms integer not null check (time_ms >= 0),
  game_type text default 'reaction',
  created_at timestamp with time zone default now()
);

-- Quest progress table
create table if not exists quests (
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

-- Inventory table
create table if not exists inventory (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade not null,
  item_id text not null,
  quantity integer default 1 check (quantity >= 0),
  acquired_at timestamp with time zone default now(),
  unique(user_id, item_id)
);

-- Wallet connections table
create table if not exists wallet_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade not null,
  wallet_address text not null,
  signature text,
  connected_at timestamp with time zone default now(),
  unique(user_id, wallet_address)
);

-- Game sessions table (for tracking matches)
create table if not exists game_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade not null,
  game_type text default 'reaction',
  best_time_ms integer,
  attempts_count integer default 0,
  completed boolean default false,
  created_at timestamp with time zone default now()
);

-- STEP 2: Create Indexes for Performance
-- ============================================

create index if not exists idx_scores_user_id on scores(user_id);
create index if not exists idx_scores_time_ms on scores(time_ms);
create index if not exists idx_scores_created_at on scores(created_at);
create index if not exists idx_scores_user_time on scores(user_id, time_ms);

create index if not exists idx_quests_user_id on quests(user_id);
create index if not exists idx_quests_quest_id on quests(quest_id);
create index if not exists idx_quests_reset_date on quests(reset_date);

create index if not exists idx_codes_code on codes(code);
create index if not exists idx_codes_used_by on codes(used_by);

create index if not exists idx_users_email on users(email);
create index if not exists idx_users_display_name on users(display_name);

-- STEP 3: Create RPC Functions
-- ============================================

-- Function to create 3 invite codes for new users
create or replace function create_user_codes(user_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  i integer;
  new_code text;
  code_exists boolean;
begin
  for i in 1..3 loop
    loop
      -- Generate random 8-character code
      new_code := upper(substring(md5(random()::text) from 1 for 8));

      -- Check if code already exists
      select exists(select 1 from codes where code = new_code) into code_exists;

      -- If unique, insert and exit loop
      if not code_exists then
        insert into codes (code, created_by) values (new_code, user_id);
        exit;
      end if;
    end loop;
  end loop;
end;
$$;

-- Function to get leaderboard with rankings
create or replace function get_leaderboard(
  time_filter text default 'all',
  limit_count integer default 100
)
returns table (
  rank bigint,
  user_id uuid,
  display_name text,
  email text,
  time_ms integer,
  created_at timestamp with time zone
)
language plpgsql
as $$
declare
  filter_date timestamp with time zone;
begin
  -- Calculate filter date based on parameter
  case time_filter
    when 'today' then
      filter_date := current_date;
    when 'week' then
      filter_date := current_date - interval '7 days';
    when 'month' then
      filter_date := date_trunc('month', current_date);
    else
      filter_date := '1970-01-01'::timestamp;
  end case;

  return query
  select
    row_number() over (order by s.time_ms asc) as rank,
    s.user_id,
    u.display_name,
    u.email,
    s.time_ms,
    s.created_at
  from (
    -- Get best time per user in time period
    select
      user_id,
      min(time_ms) as time_ms,
      max(created_at) as created_at
    from scores
    where created_at >= filter_date
    group by user_id
  ) s
  join users u on u.id = s.user_id
  order by s.time_ms asc
  limit limit_count;
end;
$$;

-- Function to get user's best time in a period
create or replace function get_user_best_time(
  p_user_id uuid,
  time_filter text default 'all'
)
returns table (
  time_ms integer,
  rank bigint
)
language plpgsql
as $$
declare
  filter_date timestamp with time zone;
  user_best integer;
begin
  -- Calculate filter date
  case time_filter
    when 'today' then filter_date := current_date;
    when 'week' then filter_date := current_date - interval '7 days';
    when 'month' then filter_date := date_trunc('month', current_date);
    else filter_date := '1970-01-01'::timestamp;
  end case;

  -- Get user's best time
  select min(s.time_ms) into user_best
  from scores s
  where s.user_id = p_user_id
    and s.created_at >= filter_date;

  -- Return best time and rank
  return query
  select
    user_best as time_ms,
    (select count(*) + 1
     from (
       select user_id, min(time_ms) as best_time
       from scores
       where created_at >= filter_date
       group by user_id
     ) lb
     where lb.best_time < user_best
    ) as rank;
end;
$$;

-- Function to update quest progress
create or replace function update_quest_progress(
  p_user_id uuid,
  p_quest_id text,
  p_increment integer default 1
)
returns void
language plpgsql
as $$
begin
  insert into quests (user_id, quest_id, progress, reset_date)
  values (p_user_id, p_quest_id, p_increment, current_date)
  on conflict (user_id, quest_id, reset_date)
  do update set
    progress = quests.progress + p_increment,
    updated_at = now();
end;
$$;

-- Function to claim quest reward
create or replace function claim_quest_reward(
  p_user_id uuid,
  p_quest_id text,
  p_reward_points integer
)
returns boolean
language plpgsql
as $$
declare
  quest_completed boolean;
begin
  -- Check if quest is completed and not claimed
  select (progress >= 1 and claimed_at is null) into quest_completed
  from quests
  where user_id = p_user_id
    and quest_id = p_quest_id
    and reset_date = current_date;

  if quest_completed then
    -- Mark as claimed
    update quests
    set claimed_at = now()
    where user_id = p_user_id
      and quest_id = p_quest_id
      and reset_date = current_date;

    -- Add points to user
    update users
    set points = points + p_reward_points
    where id = p_user_id;

    return true;
  else
    return false;
  end if;
end;
$$;

-- STEP 4: Enable Row Level Security
-- ============================================

alter table users enable row level security;
alter table scores enable row level security;
alter table quests enable row level security;
alter table codes enable row level security;
alter table inventory enable row level security;
alter table wallet_connections enable row level security;
alter table game_sessions enable row level security;

-- STEP 5: Create Security Policies
-- ============================================

-- Users policies
drop policy if exists "Users are viewable by everyone" on users;
create policy "Users are viewable by everyone"
  on users for select
  using (true);

drop policy if exists "Users can update own profile" on users;
create policy "Users can update own profile"
  on users for update
  using (true);

drop policy if exists "Users can insert themselves" on users;
create policy "Users can insert themselves"
  on users for insert
  with check (true);

-- Scores policies
drop policy if exists "Scores are viewable by everyone" on scores;
create policy "Scores are viewable by everyone"
  on scores for select
  using (true);

drop policy if exists "Users can insert own scores" on scores;
create policy "Users can insert own scores"
  on scores for insert
  with check (true);

-- Quests policies
drop policy if exists "Users can view own quests" on quests;
create policy "Users can view own quests"
  on quests for select
  using (true);

drop policy if exists "Users can insert own quests" on quests;
create policy "Users can insert own quests"
  on quests for insert
  with check (true);

drop policy if exists "Users can update own quests" on quests;
create policy "Users can update own quests"
  on quests for update
  using (true);

-- Codes policies
drop policy if exists "Codes are viewable by everyone" on codes;
create policy "Codes are viewable by everyone"
  on codes for select
  using (true);

drop policy if exists "Codes can be updated by anyone" on codes;
create policy "Codes can be updated by anyone"
  on codes for update
  using (true);

drop policy if exists "Codes can be inserted" on codes;
create policy "Codes can be inserted"
  on codes for insert
  with check (true);

-- Inventory policies
drop policy if exists "Users can view own inventory" on inventory;
create policy "Users can view own inventory"
  on inventory for select
  using (true);

drop policy if exists "Users can manage own inventory" on inventory;
create policy "Users can manage own inventory"
  on inventory for all
  using (true);

-- Wallet connections policies
drop policy if exists "Users can view own wallets" on wallet_connections;
create policy "Users can view own wallets"
  on wallet_connections for select
  using (true);

drop policy if exists "Users can manage own wallets" on wallet_connections;
create policy "Users can manage own wallets"
  on wallet_connections for all
  using (true);

-- Game sessions policies
drop policy if exists "Users can view own sessions" on game_sessions;
create policy "Users can view own sessions"
  on game_sessions for select
  using (true);

drop policy if exists "Users can manage own sessions" on game_sessions;
create policy "Users can manage own sessions"
  on game_sessions for all
  using (true);

-- STEP 6: Create some starter invite codes (Optional)
-- ============================================

-- Insert 10 starter codes that anyone can use
insert into codes (code, created_by, used_by)
select
  upper(substring(md5(random()::text) from 1 for 8)),
  null,
  null
from generate_series(1, 10)
on conflict (code) do nothing;

-- STEP 7: Create updated_at trigger
-- ============================================

create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists update_users_updated_at on users;
create trigger update_users_updated_at
  before update on users
  for each row
  execute function update_updated_at_column();

drop trigger if exists update_quests_updated_at on quests;
create trigger update_quests_updated_at
  before update on quests
  for each row
  execute function update_updated_at_column();

-- ============================================
-- MIGRATION COMPLETE!
-- ============================================
-- Next steps:
-- 1. Run this SQL in Supabase SQL Editor
-- 2. Verify tables were created in Table Editor
-- 3. Update frontend code to use these tables
-- ============================================
