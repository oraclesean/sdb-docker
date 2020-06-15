set echo off
conn app/app@sh00pdb1
alter session enable shard ddl;
show con_name
show user

set echo off
accept xx char prompt 'Create countries table:'
prompt
set echo on

  create sharded table countries (
         country_id           varchar2(3)   not null
,        country_name         varchar2(40)  not null
,        constraint country_p 
         primary key (country_id))
         partition by list (country_id) (
         partition americas  values ('CAN', 'USA') tablespace northamerica_ts
,        partition europe_uk values ('GBR')        tablespace europe_uk_ts
,        partition europe_eu values ('FRA', 'GER') tablespace europe_eu_ts
,        partition apac      values ('AUS', 'JPN') tablespace apac_ts);

set echo off
accept xx char prompt 'Create customers table:'
prompt
set echo on

  create sharded table customers (
         customer_id          number        not null 
,        country_id           varchar2(3)   not null
,        first_name           varchar2(50)  not null
,        last_name            varchar2(50)  not null
,        city                 varchar2(50)  not null
,        constraint customers_p
         primary key (customer_id, country_id)
,        constraint customers_fk_countries
         foreign key (country_id)
         references countries on delete cascade)
         partition by reference (customers_fk_countries);

set echo off
accept xx char prompt 'Create sharded sequence; add default:'
prompt
set echo on

  create sequence customers_seq shard;
   alter table customers modify (customer_id default customers_seq.nextval);

set echo off
accept xx char prompt 'Create accounts table:'
prompt
set echo on

  create sharded table accounts (
         account_id           number        not null
,        customer_id          number        not null
,        country_id           varchar2(3)   not null
,        account_balance      number        not null
,        constraint accounts_p
         primary key (account_id, customer_id, country_id)
,        constraint accounts_fk_customers
         foreign key (customer_id, country_id)
         references customers on delete cascade)
         partition by reference (accounts_fk_customers);

set echo off
accept xx char prompt 'Create sharded sequence; add default:'
prompt
set echo on

  create sequence accounts_seq shard;
   alter table accounts modify (account_id default accounts_seq.nextval);

set echo off
accept xx char prompt 'Create transactions table:'
prompt
set echo on

  create sharded table transactions (
         transaction_id       number        not null
,        account_id           number        not null
,        customer_id          number        not null
,        country_id           varchar2(3)   not null
,        txn_date             date          not null
,        txn_amt              number        not null
,        currency_code        varchar2(3)   default 'USD' not null 
,        constraint transactions_p
         primary key (transaction_id, account_id, customer_id, country_id)
,        constraint transactions_fk_accounts
         foreign key (account_id, customer_id, country_id)
         references accounts on delete cascade)
         partition by reference (transactions_fk_accounts);

set echo off
accept xx char prompt 'Create sharded sequence; add defaults:'
prompt
set echo on

  create sequence transactions_seq shard;
   alter table transactions modify (transaction_id default transactions_seq.nextval);
   alter table transactions modify (txn_date default sysdate);

