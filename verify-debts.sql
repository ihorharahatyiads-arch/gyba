begin;
insert into auth.users(id,aud,role,email) values
 ('a1111111-1111-4111-8111-111111111111','authenticated','authenticated','finflow-test-a@example.invalid'),
 ('b2222222-2222-4222-8222-222222222222','authenticated','authenticated','finflow-test-b@example.invalid');
insert into public.debts(id,user_id,direction,party,currency,amount_minor) values
 ('a3333333-3333-4333-8333-333333333333','a1111111-1111-4111-8111-111111111111','payable','Test A','UAH',1000),
 ('b4444444-4444-4444-8444-444444444444','b2222222-2222-4222-8222-222222222222','receivable','Test B','USD',5000);
set local role authenticated;
set local request.jwt.claim.sub='a1111111-1111-4111-8111-111111111111';
do $$ declare n integer; remaining bigint; blocked boolean; begin
 select count(*) into n from public.debts;
 if n<>1 then raise exception 'FAIL: debt isolation';end if;
 remaining:=public.repay_debt('a3333333-3333-4333-8333-333333333333',400);
 if remaining<>600 then raise exception 'FAIL: partial repayment';end if;
 blocked:=false;
 begin perform public.repay_debt('a3333333-3333-4333-8333-333333333333',601);
 exception when raise_exception then if sqlerrm='Сумма больше остатка долга' then blocked:=true;else raise;end if;end;
 if not blocked then raise exception 'FAIL: overpayment allowed';end if;
 blocked:=false;
 begin perform public.repay_debt('b4444444-4444-4444-8444-444444444444',1);
 exception when raise_exception then if sqlerrm='Долг не найден' then blocked:=true;else raise;end if;end;
 if not blocked then raise exception 'FAIL: foreign debt repayment';end if;
 blocked:=false;
 begin insert into public.debts(user_id,direction,party,currency,amount_minor) values('b2222222-2222-4222-8222-222222222222','payable','Forged','UAH',1);
 exception when insufficient_privilege then blocked:=true;end;
 if not blocked then raise exception 'FAIL: ownership forgery';end if;
 remaining:=public.repay_debt('a3333333-3333-4333-8333-333333333333',600);
 if remaining<>0 then raise exception 'FAIL: full repayment';end if;
end $$;
reset role;
rollback;
select 'PASS: debt isolation, ownership protection, partial/full repayment and overpayment protection; fixtures rolled back' as result;
