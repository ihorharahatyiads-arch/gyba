-- Disposable verification. All fixtures are rolled back; no passwords or persistent users.
begin;
insert into auth.users(id,aud,role,email) values
 ('a1111111-1111-4111-8111-111111111111','authenticated','authenticated','finflow-test-a@example.invalid'),
 ('b2222222-2222-4222-8222-222222222222','authenticated','authenticated','finflow-test-b@example.invalid');
insert into public.accounts(id,user_id,name,currency,opening_minor) values
 ('a3333333-3333-4333-8333-333333333333','a1111111-1111-4111-8111-111111111111','RLS A','UAH',100),
 ('b4444444-4444-4444-8444-444444444444','b2222222-2222-4222-8222-222222222222','RLS B','USD',0);
insert into public.categories(id,user_id,name) values
 ('a5555555-5555-4555-8555-555555555555','a1111111-1111-4111-8111-111111111111','RLS A'),
 ('b6666666-6666-4666-8666-666666666666','b2222222-2222-4222-8222-222222222222','RLS B');
set local role authenticated;
set local request.jwt.claim.sub='a1111111-1111-4111-8111-111111111111';
do $$ declare n integer; blocked boolean; begin
 select count(*) into n from public.accounts;
 if n<>1 then raise exception 'FAIL: cross-user account read'; end if;
 update public.accounts set name='tampered' where id='b4444444-4444-4444-8444-444444444444';
 get diagnostics n=row_count;
 if n<>0 then raise exception 'FAIL: cross-user update'; end if;
 blocked:=false;
 begin insert into public.accounts(user_id,name,currency) values('b2222222-2222-4222-8222-222222222222','forged','UAH');
 exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'FAIL: forged ownership insert'; end if;
 blocked:=false;
 begin insert into public.transactions(user_id,account_id,category_id,kind,amount_minor,date)
 values(auth.uid(),'b4444444-4444-4444-8444-444444444444','a5555555-5555-4555-8555-555555555555','expense',100,current_date);
 exception when foreign_key_violation then blocked:=true; end;
 if not blocked then raise exception 'FAIL: foreign account reference'; end if;
 insert into public.recurring(id,user_id,account_id,category_id,kind,amount_minor,next_date,interval_months,note)
 values('a7777777-7777-4777-8777-777777777777',auth.uid(),'a3333333-3333-4333-8333-333333333333','a5555555-5555-4555-8555-555555555555','expense',29,current_date,1,'RLS test');
 perform public.post_recurring('a7777777-7777-4777-8777-777777777777');
 select count(*) into n from public.transactions where note='RLS test' and amount_minor=29;
 if n<>1 then raise exception 'FAIL: recurring transaction not persisted'; end if;
 if not exists(select 1 from public.recurring where id='a7777777-7777-4777-8777-777777777777' and next_date=(current_date+interval '1 month')::date) then raise exception 'FAIL: recurring next date'; end if;

 insert into public.recurring(id,user_id,account_id,category_id,kind,amount_minor,next_date,interval_months,note)
 values('a8888888-8888-4888-8888-888888888888',auth.uid(),'a3333333-3333-4333-8333-333333333333','a5555555-5555-4555-8555-555555555555','expense',101,(now() at time zone 'Europe/Kyiv')::date,0,'oneoff verification');
 perform public.post_recurring('a8888888-8888-4888-8888-888888888888');
 if not exists(select 1 from public.recurring where id='a8888888-8888-4888-8888-888888888888' and completed_at is not null) then raise exception 'FAIL: one-off not completed'; end if;
 select count(*) into n from public.transactions where note='oneoff verification';
 if n<>1 then raise exception 'FAIL: one-off ledger entry'; end if;
 blocked:=false;
 begin perform public.post_recurring('a8888888-8888-4888-8888-888888888888');
 exception when raise_exception then if sqlerrm='Разовый платёж уже проведён' then blocked:=true;else raise;end if;end;
 if not blocked then raise exception 'FAIL: one-off posted twice'; end if;
 insert into public.recurring(id,user_id,account_id,category_id,kind,amount_minor,next_date,interval_months,note)
 values('a9999999-9999-4999-8999-999999999999',auth.uid(),'a3333333-3333-4333-8333-333333333333','a5555555-5555-4555-8555-555555555555','expense',101,(now() at time zone 'Europe/Kyiv')::date+1,0,'future verification');
 blocked:=false;
 begin perform public.post_recurring('a9999999-9999-4999-8999-999999999999');
 exception when raise_exception then if sqlerrm='Дата платежа ещё не наступила' then blocked:=true;else raise;end if;end;
 if not blocked then raise exception 'FAIL: future payment posted early'; end if;

end $$;
reset role;
rollback;
select 'PASS: own records readable; other user read/update/insert and account reference blocked; recurring date, one-off completion, duplicate and future payment protection verified; all fixtures rolled back' as result;
