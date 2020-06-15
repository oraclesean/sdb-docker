conn app/app@sh00pdb1
alter session enable shard ddl;

set echo off
accept xx char prompt 'Can subpartitions be created on a reference partition?'
prompt
set echo on

  create sharded table subpartitions_1 (
         transaction_id       number        not null
,        account_id           number        not null
,        customer_id          number        not null
,        country_id           varchar2(3)   not null
,        txn_date             date          not null
,        currency_code        varchar2(3)   default 'USD' not null 
,        constraint subpartitions_p
         primary key (transaction_id, account_id, customer_id, country_id)
,        constraint subpartitions_fk_accounts
         foreign key (account_id, customer_id, country_id)
         references accounts on delete cascade)
         partition by reference (subpartitions_fk_accounts)
         subpartition by range(txn_date)
         subpartition template
        (subpartition p_2019 values less than (to_date('2020-01-01', 'YYYY-MM-DD'))
        (subpartition p_2020 values less than (to_date('2021-01-01', 'YYYY-MM-DD'))
        (subpartition future values less than (maxvalue))
         partitions auto;

set echo off
prompt No!
