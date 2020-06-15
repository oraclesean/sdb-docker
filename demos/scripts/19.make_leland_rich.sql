set echo off
alter session set nls_date_format='YYYY-MM-DD HH24:MI:SS';
set numw 30 pages 999 lines 110 
col account_balance for 999,999,999
col txn_amt for 999,999,999
col country_id for a7 heading "COUNTRY|ID"
conn app/app@sh13pdb1
show con_name
show user

accept xx char prompt 'Make Leland rich!'
prompt
set echo on

  insert into transactions (
         account_id
,        customer_id
,        country_id
,        txn_amt
,        currency_code)
  select a.account_id
,        a.customer_id
,        a.country_id
,        50000000
,        'AUD'
    from accounts             a
,        customers            c
   where a.customer_id        = c.customer_id
     and a.country_id         = c.country_id
     and c.first_name         = 'Leland' 
     and c.last_name          = 'Van Lew';

set echo off
accept xx char prompt 'Finish making Leland rich!'
prompt
set echo on

  update accounts             a
     set account_balance      = 50000000
   where customer_id          = (
  select customer_id
    from customers
   where country_id           = 'AUS'
     and first_name           = 'Leland'
     and last_name            = 'Van Lew');

set echo off
commit;

accept xx char prompt 'How rich is Leland?'
prompt
set echo on

  select a.account_id, a.account_balance, t.txn_amt, t.txn_date
    from accounts             a
,        transactions         t
,        customers            c
   where c.customer_id        = a.customer_id
     and c.country_id         = a.country_id
     and a.account_id         = t.account_id
     and a.customer_id        = t.customer_id
     and a.country_id         = t.country_id
     and c.country_id         = 'AUS'
     and c.first_name         = 'Leland'
     and c.last_name          = 'Van Lew';

set echo off
