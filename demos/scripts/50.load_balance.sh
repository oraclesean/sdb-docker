 for i in {1..15}
  do echo "set feedback off head off
col countries for a50
col host_name for a10
select host_name, listagg(country_id, ', ') within group (order by country_id) as countries from countries, v\$instance group by host_name;" | sqlplus -S app/app@'(description=(ADDRESS=(HOST=SH00)(PORT=1571)(PROTOCOL=tcp))(connect_data=(service_name=oltp_rw_svc.sdb-user.sdb-user)))'
done
