col file_name for a95
col tablespace_name for a15
break on tablespace_name
show user
show con_name

set echo off
accept xx char prompt 'List tablespaces and files:'
prompt
set echo on

  select tablespace_name, file_name
    from dba_data_files
order by tablespace_name;

set echo off
clear breaks
