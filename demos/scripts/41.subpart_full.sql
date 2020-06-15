conn app/app@sh00pdb1
alter session enable shard ddl;

set echo off
accept xx char prompt 'Subpartitions require the PARENT clause and explicit partitioning'
prompt
set echo on

prompt Create subpartitions using the PARENT clause:

  create sharded table subpartitions_2 (
         customer_id          number        not null 
,        country_id           varchar2(3)   not null
,        action_date          date          not null
,        constraint subpartitions_2_p
         primary key (customer_id, country_id, action_date)
,        constraint subpartitions_2_fk_countries
         foreign key (country_id)
         references countries on delete cascade)
-- PARENT clause:
         parent countries
         partition by list (country_id)
            subpartition by range (action_date)
        (partition americas  values ('CAN', 'USA')
           (subpartition p_na_2020 values less than (to_date('2021-01-01', 'YYYY-MM-DD'))
                         tablespace northamerica_ts
,           subpartition future_na values less than (maxvalue)
                         tablespace northamerica_ts)
,        partition europe_uk values ('GBR')
           (subpartition p_uk_2020 values less than (to_date('2021-01-01', 'YYYY-MM-DD'))
                         tablespace europe_uk_ts
,           subpartition future_uk values less than (maxvalue)
                         tablespace europe_uk_ts)
,        partition europe_eu values ('FRA', 'GER')
           (subpartition p_eu_2020 values less than (to_date('2021-01-01', 'YYYY-MM-DD'))
                         tablespace europe_eu_ts
,           subpartition future_eu values less than (maxvalue)
                         tablespace europe_eu_ts)
,        partition apac      values ('AUS', 'JPN')
           (subpartition p_apac_2020 values less than (to_date('2021-01-01', 'YYYY-MM-DD'))
                         tablespace apac_ts
,           subpartition future_apac values less than (maxvalue)
                         tablespace apac_ts));

set echo off
