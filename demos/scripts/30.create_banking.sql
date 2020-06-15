conn app/app@sh00pdb1
alter session enable shard ddl;

set echo off
accept xx char prompt 'Create the BANKING package:'
prompt
set echo on

   create or replace package banking
       as

          overdrawn           exception;
          bad_currency        exception;

 function get_customer_id (
          countryid           in  varchar2
,         firstname           in  varchar2
,         lastname            in  varchar2)
   return number;

 function get_customer_account (
          customerid          in  varchar2)
   return number;

 function get_account_balance (
          accountid           in  number)
   return number;

procedure do_transaction (
          accountid           in  number
,         txnamount           in  number
,         currencycode        in  varchar2 default 'USD'
,         newbalance          out number);
      end;
/

   create or replace package body banking
       as
 function get_customer_id (
          countryid           in  varchar2
,         firstname           in  varchar2
,         lastname            in  varchar2)
   return number
       as
          v_customer_id       customers.customer_id%TYPE;
    begin
            select customer_id
              into v_customer_id
              from customers
             where country_id      = countryid
               and first_name      = firstname
               and last_name       = lastname;

   return v_customer_id;

exception
     when no_data_found
     then return 0;
      end get_customer_id;

 function get_customer_account (
          customerid          in  varchar2)
   return number
       as
          v_account_id        accounts.account_id%TYPE;
    begin
            select account_id
              into v_account_id
              from accounts
             where customer_id     = customerid;

   return v_account_id;

exception
     when no_data_found
     then return 0;
      end get_customer_account;

 function get_account_balance (
          accountid           in  number)
   return number
       as
          v_balance           accounts.account_balance%TYPE;
    begin
            select account_balance
              into v_balance
              from accounts
             where account_id      = accountid;

   return v_balance;

exception
     when no_data_found
     then return 0;
      end get_account_balance;

procedure do_transaction (
          accountid           in  number
,         txnamount           in  number
,         currencycode        in  varchar2 default 'USD'
,         newbalance          out number)
       as
          v_customer_id       accounts.customer_id%TYPE;
          v_country_id        accounts.country_id%TYPE;
          v_balance           accounts.account_balance%TYPE;
          v_new_balance       accounts.account_balance%TYPE;
          v_currency_check    number;
    begin
            select customer_id
          ,        country_id
          ,        account_balance
              into v_customer_id
          ,        v_country_id
          ,        v_balance
              from accounts
             where account_id      = accountid;

          /* Negative transactions represent withdrawals */
          v_new_balance := v_balance + txnamount;

       if v_new_balance < 0
     then newbalance := v_balance;
          raise overdrawn;
     else newbalance := v_new_balance;
   end if;

            select count(currency_code)
              into v_currency_check
              from currencies
             where currency_code   = currencycode;

       if v_currency_check = 0
     then newbalance := v_balance;
          raise bad_currency;
   end if;

            insert into transactions (
                   account_id
          ,        customer_id
          ,        country_id
          ,        txn_date
          ,        txn_amt
          ,        currency_code)
            values (
                   accountid
          ,        v_customer_id
          ,        v_country_id
          ,        sysdate
          ,        txnamount
          ,        currencycode);

            update accounts
               set account_balance = v_new_balance
             where account_id      = accountid
               and customer_id     = v_customer_id
               and country_id      = v_country_id;

          commit;

exception
     when no_data_found
     then dbms_output.put_line('Invalid account');
     when overdrawn
     then dbms_output.put_line('Insufficient funds');
     when bad_currency
     then dbms_output.put_line('Invalid currency code');
     when others
     then dbms_output.put_line(SQLERRM);
      end do_transaction;

      end;
/

set echo off
