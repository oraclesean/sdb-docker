set echo off
accept xx char prompt 'Run BANKING.DO_TRANSACTION to withdraw funds:'
prompt
set echo on

  declare
          bal number;
    begin
          dbms_output.put_line('Withdraw $30');
          banking.do_transaction(:acctid, -30, 'USD', bal);
          dbms_output.put_line(bal);
      end;
/

set echo off
