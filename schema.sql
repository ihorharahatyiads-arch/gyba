-- Apply once in a new Supabase project, SQL Editor.
begin;
create table public.accounts (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null check(length(trim(name)) between 1 and 80), currency text not null check(currency in ('UAH','USD','EUR')),
 opening_minor bigint not null default 0 check(abs(opening_minor)<=999999999999), unique(id,user_id)
);
create table public.categories (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null check(length(trim(name)) between 1 and 80), unique(id,user_id), unique(user_id,name)
);
create table public.transactions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 account_id uuid not null, category_id uuid not null, kind text not null check(kind in ('income','expense')),
 amount_minor bigint not null check(amount_minor>0 and amount_minor<=999999999999), date date not null,
 note text not null default '' check(length(note)<=200), created_at timestamptz not null default now(),
 foreign key(account_id,user_id) references public.accounts(id,user_id), foreign key(category_id,user_id) references public.categories(id,user_id)
);
create table public.budgets (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 category_id uuid not null, currency text not null check(currency in ('UAH','USD','EUR')), month date not null check(extract(day from month)=1),
 amount_minor bigint not null check(amount_minor>0 and amount_minor<=999999999999),
 foreign key(category_id,user_id) references public.categories(id,user_id),unique(user_id,category_id,currency,month)
);
create table public.recurring (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 account_id uuid not null, category_id uuid not null, kind text not null check(kind in ('income','expense')),
 amount_minor bigint not null check(amount_minor>0 and amount_minor<=999999999999), next_date date not null,
 interval_months integer not null check(interval_months in (0,1,3,12)), note text not null default '' check(length(note)<=200),
 last_posted_at timestamptz, completed_at timestamptz,
 foreign key(account_id,user_id) references public.accounts(id,user_id),foreign key(category_id,user_id) references public.categories(id,user_id)
);
create index transactions_owner_date on public.transactions(user_id,date);
create index accounts_owner on public.accounts(user_id);
create index recurring_owner on public.recurring(user_id);
create index categories_owner on public.categories(user_id);
create index budgets_owner on public.budgets(user_id);
do $$ declare t text; begin foreach t in array array['accounts','categories','transactions','budgets','recurring'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('create policy own_records on public.%I for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id)',t);
 execute format('revoke all on public.%I from anon',t);
 execute format('grant select,insert,update,delete on public.%I to authenticated',t);
end loop; end $$;
-- A transaction and next due date are committed together. Row lock prevents concurrent double clicks.
create or replace function public.post_recurring(rule_id uuid) returns uuid language plpgsql security invoker set search_path=public as $$
declare r public.recurring; new_id uuid;
begin
 select * into r from public.recurring where id=rule_id and user_id=auth.uid() for update;
 if not found then raise exception 'Платёж не найден'; end if;
 if r.completed_at is not null then raise exception 'Разовый платёж уже проведён'; end if;
 if r.last_posted_at > now()-interval '10 seconds' then raise exception 'Платёж уже проведён. Обновите страницу.'; end if;
 if r.next_date > (now() at time zone 'Europe/Kyiv')::date then raise exception 'Дата платежа ещё не наступила'; end if;
 insert into public.transactions(user_id,account_id,category_id,kind,amount_minor,date,note)
 values(auth.uid(),r.account_id,r.category_id,r.kind,r.amount_minor,r.next_date,r.note) returning id into new_id;
 if r.interval_months=0 then
 update public.recurring set completed_at=now(),last_posted_at=now() where id=rule_id;
 else
 update public.recurring set next_date=(r.next_date+make_interval(months=>r.interval_months))::date,last_posted_at=now() where id=rule_id;
 end if;
 return new_id;
end $$;
revoke all on function public.post_recurring(uuid) from public,anon;
grant execute on function public.post_recurring(uuid) to authenticated;
commit;
