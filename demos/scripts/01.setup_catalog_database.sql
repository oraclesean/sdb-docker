   alter user gsmcatuser account unlock;
   alter user gsmcatuser identified by oracle;

   alter session set container=sh00pdb1;

   alter user gsmcatuser account unlock;

  create user sdbadmin identified by oracle;
   alter user sdbadmin identified by oracle;
   grant connect, create session, gsmadmin_role to sdbadmin;

-- Set up the scheduler agent
exec dbms_xdb.sethttpport(8080);
@?/rdbms/admin/prvtrsch.plb
exec dbms_scheduler.set_agent_registration_pass('oracle');
