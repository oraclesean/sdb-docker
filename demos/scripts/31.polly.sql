set serverout on
var custid number
var acctid number

set echo off
accept xx char prompt 'Run BANKING.GET_CUSTOMER function on a shard:'
prompt
set echo on

   begin
  select banking.get_customer_id(country_id, first_name, last_name)
    into :custid
    from customers
   where first_name = 'Polly'
     and last_name  = 'Prince';

set echo off
accept xx char prompt 'Run BANKING.GET_CUSTOMER_ACCOUNT function on a shard:'
prompt
set echo on

  select banking.get_customer_account(customer_id)
    into :acctid
    from customers
   where first_name = 'Polly'
     and last_name  = 'Prince';
end;
/

set echo off
accept xx char prompt 'Run BANKING.DO_TRANSACTION to deposit $100:'
prompt
set echo on

  declare
          bal number;
    begin
          dbms_output.put_line('Deposit $100');
          banking.do_transaction(:acctid, 100, 'USD', bal);
          dbms_output.put_line('New balance: ' || bal);
      end;
/

set echo off
accept xx char prompt 'Run BANKING.DO_TRANSACTION to withdraw $30:'
prompt
set echo on

  declare
          bal number;
    begin
          dbms_output.put_line('Withdraw $30');
          banking.do_transaction(:acctid, -30, 'USD', bal);
          dbms_output.put_line('New balance: ' || bal);
      end;
/

set echo off
