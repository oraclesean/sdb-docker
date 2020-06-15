set echo off
conn app/app@sh00pdb1
alter session enable shard ddl;
show con_name
show user

accept xx char prompt 'Create a new sharded table with a FK against a duplicated table:'
prompt
set echo on

  create sharded table dup_fk_test (
         transaction_id       number        not null
,        account_id           number        not null
,        customer_id          number        not null
,        country_id           varchar2(3)   not null
,        currency_code        varchar2(3)   default 'USD' not null 
,        constraint dup_fk_test_p
         primary key (transaction_id, account_id, customer_id, country_id)
,        constraint dup_fk_test_fk_accounts
         foreign key (account_id, customer_id, country_id)
         references accounts on delete cascade
,        constraint dup_fk_test_fk_currencies
         foreign key (currency_code)
         references currencies on delete cascade)
         partition by reference (dup_fk_test_fk_accounts);

set echo off
