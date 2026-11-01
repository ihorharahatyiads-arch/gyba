begin;
alter table public.recurring add column if not exists completed_at timestamptz;
alter table public.recurring drop constraint if exists recurring_interval_months_check;
alter table public.recurring add constraint recurring_interval_months_check check(interval_months in (0,1,3,12));
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
