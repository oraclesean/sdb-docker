set echo off numw 30 pages 999 lines 116
conn app/app@sh00pdb1
show con_name
show user

set echo off
accept xx char prompt 'Create accounts for customers w/insert as select:'
prompt
set echo on

  insert into accounts
  select accounts_seq.nextval, c.customer_id, c.country_id, 0
    from customers  c
   where country_id not in ('CAN', 'USA');

set echo off
prompt 'Illegal!'
prompt
accept xx char prompt 'This is legal:'
prompt
set echo on

  select 'insert into accounts (customer_id, country_id, account_balance) values (' || customer_id || ', ''' || country_id || ''', 0);'
    from customers
   where country_id not in ('CAN', 'USA');

prompt Oracle 19c Sharding doesn't allow cross-shard DML; this is a new feature in 20c.
commit;
