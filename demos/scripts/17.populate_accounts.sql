set echo off numw 30 pages 999 lines 116 
conn app/app@sh11pdb1
show con_name
show user

accept xx char prompt 'Create accounts for all customers on the local shard:'
prompt
set echo on

  insert into accounts
  select accounts_seq.nextval, c.customer_id, c.country_id, 0
    from customers  c;

set echo off
commit;
