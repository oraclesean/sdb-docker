set echo off
accept xx char prompt 'Insert currencies:'
prompt
set echo on

  insert into currencies (currency_code, currency_name) values ('AUD', 'Australian Dollar');
  insert into currencies (currency_code, currency_name) values ('CAD', 'Canadian Dollar');
  insert into currencies (currency_code, currency_name) values ('EUR', 'Euro');
  insert into currencies (currency_code, currency_name) values ('GBP', 'Pound Sterling');
  insert into currencies (currency_code, currency_name) values ('JPY', 'Japanese Yen');
  insert into currencies (currency_code, currency_name) values ('USD', 'US Dollar');

set echo off
accept xx char prompt 'Insert currency codes:'
prompt
set echo on

  insert into exchange_rates (currency_code, ref_currency_code, exchange_rate) values ('AUD', 'USD', 1.484337);
  insert into exchange_rates (currency_code, ref_currency_code, exchange_rate) values ('CAD', 'USD', 1.3085);
  insert into exchange_rates (currency_code, ref_currency_code, exchange_rate) values ('EUR', 'USD', 0.885653);
  insert into exchange_rates (currency_code, ref_currency_code, exchange_rate) values ('GBP', 'USD', 0.675357);
  insert into exchange_rates (currency_code, ref_currency_code, exchange_rate) values ('JPY', 'USD', 108.349939);
  insert into exchange_rates (currency_code, ref_currency_code, exchange_rate) values ('USD', 'USD', 1);

set echo off
accept xx char prompt 'Insert country data:'
prompt
set echo on

  insert into countries values ('AUS', 'Australia');
  insert into countries values ('CAN', 'Canada');
  insert into countries values ('FRA', 'France');
  insert into countries values ('GBR', 'United Kingdom');
  insert into countries values ('GER', 'Germany');
  insert into countries values ('JPN', 'Japan');
  insert into countries values ('USA', 'United States');

set echo off
accept xx char prompt 'Insert customer data:'
prompt
set echo on

  insert into customers (country_id, first_name, last_name, city) values ('CAN', 'Reuben', 'Feffer', 'Montreal');
  insert into customers (country_id, first_name, last_name, city) values ('JPN', 'Polly', 'Prince', 'Tokyo');
  insert into customers (country_id, first_name, last_name, city) values ('GBR', 'Sandy', 'Lyle', 'London');
  insert into customers (country_id, first_name, last_name, city) values ('GER', 'Lisa', 'Kramer', 'Berlin');
  insert into customers (country_id, first_name, last_name, city) values ('FRA', 'Claude', 'Scuba', 'Paris');
  insert into customers (country_id, first_name, last_name, city) values ('AUS', 'Leland', 'Van Lew', 'Sydney');
  insert into customers (country_id, first_name, last_name, city) values ('USA', 'Stan', 'Indursky', 'New York');

set echo off
commit;
