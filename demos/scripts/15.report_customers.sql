set echo off numw 30 pages 999 lines 116
col first_name for a10
col last_name for a10
col country_id for a7 heading "COUNTRY|ID"
conn app/app@sh00pdb1
show con_name
show user

set echo off
accept xx char prompt 'Report all customers:'
prompt
set echo on

  select c.customer_id
,        c.country_id
,        sysdate
    from customers  c;

set echo off
accept xx char prompt 'Print one customer:'
prompt
set echo on

  select c.customer_id
,        c.country_id
    from customers  c
   where first_name = 'Reuben'
     and last_name  = 'Feffer'
     and country_id = 'CAN';

set echo off
accept xx char prompt '...now add SYSDATE'
prompt
set echo on

  select c.customer_id
,        c.country_id
,        sysdate
    from customers  c
   where first_name = 'Reuben'
     and last_name  = 'Feffer'
     and country_id = 'CAN';

set echo off
prompt
prompt This is a bug!
prompt
prompt ERROR at line 7:
prompt ORA-02683: inconsistent shard schema
prompt ORA-02063: preceding line from ORA_SHARD_POOL@ORA_MULTI_TARGET

set echo off
accept xx char prompt 'The same statment works on the shard hosting the data:'
prompt

conn app/app@sh11pdb1
show user
show con_name
set echo on

  select c.customer_id
,        c.country_id
,        sysdate
    from customers  c
   where first_name = 'Reuben'
     and last_name  = 'Feffer'
     and country_id = 'CAN';

set echo off
