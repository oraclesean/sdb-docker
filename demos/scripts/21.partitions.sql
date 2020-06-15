set echo off 
col table_name for a15
col partition_name for a12
col tablespace_name for a15
break on table_name
show user
show con_name

set echo on

  select table_name, partition_name, tablespace_name, subpartition_count
    from user_tab_partitions
order by table_name, tablespace_name;

set echo off
