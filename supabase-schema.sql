-- ============================================================
-- Liz Ogumbo Site — Supabase Schema
-- Run this once in Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- 1. PROFILES ---------------------------------------------------
-- One row per signed-up user. Created automatically on signup.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  avatar_url text,
  role text not null default 'member' check (role in ('member','admin')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles are publicly readable"
  on public.profiles for select
  using (true);

create policy "users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- Auto-create a profile row whenever someone signs up
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)),
    coalesce(new.raw_user_meta_data->>'avatar_url', '')
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 2. POSTS (My Journal) -----------------------------------------
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text not null unique,
  category text not null check (category in (
    'From My Table','KenSoul','Liz Ogumbo Fashion','DeniMania',
    'Vine to Soul','Fashion Lab','Cultural Architecture','Kamatana'
  )),
  excerpt text,
  content text not null,              -- HTML paragraphs
  hero_image text,
  author_id uuid references public.profiles(id),
  author_name text not null default 'Liz Ogumbo',   -- snapshot, survives even if author account changes
  author_avatar text,
  read_time text default '3 min read',
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.posts enable row level security;

create policy "posts are publicly readable"
  on public.posts for select
  using (true);

create policy "only admins can insert posts"
  on public.posts for insert
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

create policy "only admins can update posts"
  on public.posts for update
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

create policy "only admins can delete posts"
  on public.posts for delete
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- 3. MEDIA ITEMS (Media Room) -------------------------------------
create table if not exists public.media_items (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('print','video')),
  title text not null,
  storage_path text,       -- used for print media uploaded to Supabase Storage
  external_url text,       -- used for video (YouTube link) or externally-hosted image
  thumbnail_url text,
  duration text,
  uploaded_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.media_items enable row level security;

create policy "media is publicly readable"
  on public.media_items for select
  using (true);

create policy "only admins can insert media"
  on public.media_items for insert
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

create policy "only admins can delete media"
  on public.media_items for delete
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- 4. STORAGE BUCKET for print media uploads ------------------------
insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do nothing;

create policy "public read of media bucket"
  on storage.objects for select
  using (bucket_id = 'media');

create policy "only admins can upload to media bucket"
  on storage.objects for insert
  with check (
    bucket_id = 'media'
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- 5. SEED DATA — existing posts & media so the site isn't empty on day one
insert into public.posts (title, slug, category, excerpt, content, hero_image, author_name, author_avatar, read_time, published_at)
values
(
  'The Table Was Always My Classroom',
  'the-table-was-always-my-classroom',
  'From My Table',
  'A reflection on wine, hospitality and the power of gathering.',
  '<p>Long before I understood wine as an industry, I understood it as a table. Someone pouring, someone listening, a story arriving between the second glass and the third. That''s where I actually learned about hospitality — not in a classroom, but at a table that never seemed to empty.</p>
   <p>Every culture I''ve lived in has had its own version of that table. What''s stayed constant is the role it plays: it slows people down long enough to actually see each other. That, more than any tasting note, is what I try to build into every Liz Ogumbo Wines™ experience.</p>
   <p>Wine, Wisdom &amp; Wonders™ grew out of that same instinct — the belief that the most useful wine education isn''t about memorising regions, it''s about learning to host. To pour with intention. To let a glass be an invitation rather than a performance.</p>
   <p>So if you''re building your own table, start small. One good bottle, one honest question, and the patience to let the conversation breathe. The rest tends to follow.</p>',
  'https://static.wixstatic.com/media/02ca65_599952433001451593939054b04f652b~mv2.jpg',
  'Liz Ogumbo',
  'https://static.wixstatic.com/media/02ca65_7b9c92cf080f4b809edfbe81f3a5fe5e~mv2.jpg',
  '3 min read',
  '2026-06-18T09:00:00Z'
),
(
  'Refashioning Denim for a Circular Luxury Future',
  'refashioning-denim-for-a-circular-luxury-future',
  'DeniMania',
  'Denim built the 20th century''s idea of luxury — DeniMania™ is rebuilding it for the 21st.',
  '<p>Denim built the twentieth century''s idea of everyday luxury — durable, democratic, endlessly reinvented. It''s fitting, then, that denim is also where I''ve chosen to test what circular luxury can look like for the twenty-first.</p>
   <p>DeniMania™ didn''t start as a sustainability initiative. It started as curiosity: what happens if a discarded pair of jeans is treated with the same seriousness as a bolt of silk?</p>
   <p>Our 3R Methodology™ — reclaim, reconstruct, retell — is less a production process than a discipline. Every collection has to answer three questions: what was this before, what is it becoming, and whose story does it now carry?</p>
   <p>Circular fashion is often framed as a constraint. I''d argue the opposite. Waste, treated seriously, is one of the more generous design briefs I''ve worked with.</p>',
  'https://static.wixstatic.com/media/02ca65_ec3599d135ed412aab06cc6c2cf29351~mv2.png',
  'Liz Ogumbo',
  'https://static.wixstatic.com/media/02ca65_7b9c92cf080f4b809edfbe81f3a5fe5e~mv2.jpg',
  '4 min read',
  '2026-05-27T09:00:00Z'
),
(
  'Why Africa Must Say No: We Are Not a Testing Ground',
  'why-africa-must-say-no-we-are-not-a-testing-ground',
  'Cultural Architecture',
  'On autonomy, consent, and why the continent isn''t anyone''s testing ground.',
  '<p>There''s a pattern that repeats across health, tech and agriculture alike: new interventions arrive on the continent framed as opportunity, tested at a scale and speed they''d never be permitted elsewhere.</p>
   <p>I make music and clothes and wine, but the thread underneath all of it is the same one that shows up here: who gets to author the story of a body, a community, a resource.</p>
   <p>Saying no isn''t obstruction. It''s the beginning of a real negotiation, one where communities set the terms instead of receiving them.</p>
   <p>This is advocacy I carry into every part of my work — because culture, health and autonomy were never separate conversations to begin with.</p>',
  'https://i.ytimg.com/vi/jhcMuVZlU0U/maxresdefault.jpg',
  'Liz Ogumbo',
  'https://static.wixstatic.com/media/02ca65_7b9c92cf080f4b809edfbe81f3a5fe5e~mv2.jpg',
  '4 min read',
  '2026-04-09T09:00:00Z'
)
on conflict (slug) do nothing;

insert into public.media_items (type, title, external_url, thumbnail_url, duration, created_at)
values
('print', 'Liz Ogumbo — Press Photo', 'https://static.wixstatic.com/media/02ca65_5718dc41aa6b4f029e35a133eef9ff0c~mv2.png', null, null, now()),
('print', 'Liz Ogumbo — Press Photo', 'https://static.wixstatic.com/media/02ca65_3e9ce73127cc45b1a5564bed5bfc30eb~mv2.jpeg', null, null, now()),
('print', 'Liz Ogumbo — Press Photo', 'https://static.wixstatic.com/media/02ca65_9bbf2bd7f3c940a3a2c5b7302f019bcf~mv2.jpg', null, null, now()),
('print', 'Liz Ogumbo — Press Photo', 'https://static.wixstatic.com/media/02ca65_eadb4a26df1143e18ba5b21315e5a96f~mv2.jpg', null, null, now()),
('print', 'Liz Ogumbo — Press Photo', 'https://static.wixstatic.com/media/02ca65_47d3b54fde314509be35f9136ab19911~mv2.jpg', null, null, now()),
('print', 'Liz Ogumbo — Press Photo', 'https://static.wixstatic.com/media/02ca65_2edc71a2391e4ad7a23b81b6090ab39b~mv2.png', null, null, now()),
('print', 'Liz Ogumbo — Press Photo', 'https://static.wixstatic.com/media/02ca65_76bf8569a2b1443d940d5833809116eb~mv2.png', null, null, now()),
('print', 'Liz Ogumbo — Press Photo', 'https://static.wixstatic.com/media/02ca65_9e69787b891845efaa5529c60d582cab~mv2.png', null, null, now()),
('print', 'Liz Ogumbo — Press Photo', 'https://static.wixstatic.com/media/02ca65_02a97c436c7648f083f3e0eae53664a0~mv2.png', null, null, now()),
('print', 'Liz Ogumbo — Press Photo', 'https://static.wixstatic.com/media/02ca65_8e3f5a7083204da0bbc863c507040b81~mv2.jpg', null, null, now()),
('print', 'Liz Ogumbo — Press Photo', 'https://static.wixstatic.com/media/02ca65_c51da38280134772959cf8002b9ca273~mv2.png', null, null, now()),
('video', 'Liz Ogumbo MUSIC EPK', 'https://www.youtube.com/watch?v=1wOdGlLg4vs', 'https://i.ytimg.com/vi/1wOdGlLg4vs/maxresdefault.jpg', '08:59', now()),
('video', 'Explore Liz Ogumbo''s KenSoul', 'https://www.youtube.com/watch?v=Ujqjhem2wbw', 'https://i.ytimg.com/vi/Ujqjhem2wbw/maxresdefault.jpg', '03:36', now()),
('video', 'Fertility Is A Right, Not A Lab Experiment', 'https://www.youtube.com/watch?v=jhcMuVZlU0U', 'https://i.ytimg.com/vi/jhcMuVZlU0U/maxresdefault.jpg', '06:11', now());

-- ============================================================
-- 6. MAKE YOURSELF ADMIN (run this AFTER you sign up on the site)
-- Replace the email below with the account you'll publish from.
-- ============================================================
-- update public.profiles set role = 'admin' where id = (select id from auth.users where email = 'liz@lizogumbo.com');
