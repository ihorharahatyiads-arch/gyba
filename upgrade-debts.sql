begin;
create table public.debts (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 direction text not null check(direction in ('payable','receivable')),
 party text not null check(length(trim(party)) between 1 and 100),
 currency text not null check(currency in ('UAH','USD','EUR')),
 amount_minor bigint not null check(amount_minor>0 and amount_minor<=999999999999),
 paid_minor bigint not null default 0 check(paid_minor>=0 and paid_minor<=amount_minor),
 due_date date,
 note text not null default '' check(length(note)<=500),
 created_at timestamptz not null default now()
);
create index debts_owner on public.debts(user_id);
alter table public.debts enable row level security;
create policy own_records on public.debts for all to authenticated
 using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
revoke all on public.debts from anon;
grant select,insert,update,delete on public.debts to authenticated;
create function public.repay_debt(debt_id uuid,payment_minor bigint) returns bigint language plpgsql security invoker set search_path=public as $$
declare d public.debts; remaining bigint;
begin
 select * into d from public.debts where id=debt_id and user_id=auth.uid() for update;
 if not found then raise exception 'Долг не найден';end if;
 if payment_minor is null or payment_minor<=0 then raise exception 'Введите положительную сумму';end if;
 if payment_minor>d.amount_minor-d.paid_minor then raise exception 'Сумма больше остатка долга';end if;
 update public.debts set paid_minor=paid_minor+payment_minor where id=debt_id returning amount_minor-paid_minor into remaining;
 return remaining;
end $$;
revoke all on function public.repay_debt(uuid,bigint) from public,anon;
grant execute on function public.repay_debt(uuid,bigint) to authenticated;
commit;
