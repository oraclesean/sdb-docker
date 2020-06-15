   alter session set container=sh00pdb1;
   alter session enable shard ddl;

  create user app identified by app;

   grant connect, resource, dba, all privileges to app;
   grant gsmadmin_role to app;
   grant select_catalog_role to app;
   grant execute on dbms_crypto to app;

  create tablespace NORTHAMERICA_TS
      in shardspace NORTHAMERICA
         datafile size 50m 
         extent management local 
         segment space management auto;

  create tablespace EUROPE_EU_TS
      in shardspace EUROPE etc.

  create tablespace EUROPE_UK_TS
      in shardspace EUROPE etc.

  create tablespace APAC_TS
      in shardspace ASIAPACIFIC etc.
