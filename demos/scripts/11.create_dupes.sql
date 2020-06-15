set echo off
conn app/app@sh00pdb1
alter session enable shard ddl;

accept xx char prompt 'Create a tablespace for duplicated tables:'
prompt
set echo on

  create tablespace common_data_ts
         datafile size 5m
         extent management local
         segment space management auto;

set echo off
accept xx char prompt 'Create currency table:'
prompt
set echo on

  create duplicated table currencies (
         currency_code        varchar2(3)   not null
,        currency_name        varchar2(40)  not null
,        constraint currencies_p
         primary key (currency_code))
         tablespace common_data_ts;

set echo off
accept xx char prompt 'Create exchange rate table:'
prompt
set echo on

  create duplicated table exchange_rates (
         currency_code        varchar2(3)   not null
,        ref_currency_code    varchar2(3)   not null
,        exchange_rate        number        not null
,        constraint exchange_rates_p
         primary key (currency_code, ref_currency_code)
,        constraint exchange_rates_fk_currencies_f1
         foreign key (currency_code)
         references currencies (currency_code)
,        constraint exchange_rates_fk_currencies_f2
         foreign key (ref_currency_code)
         references currencies (currency_code))
         tablespace common_data_ts;
