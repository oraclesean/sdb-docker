set echo off numw 30 pages 999 lines 116 
col first_name for a10
col last_name for a10
col country_id for a7 heading "COUNTRY|ID"
show con_name
show user

accept xx char prompt 'Report customers and accounts:'
prompt
set echo on

  select c.country_id, c.first_name, c.last_name, a.account_id
    from customers       c
,        accounts        a
   where c.country_id    = a.country_id
     and c.customer_id   = a.customer_id
order by 1;

set echo off
