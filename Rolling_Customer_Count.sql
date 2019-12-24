/******************************************************
Rolling Customer Count with Google BigQuery
******************************************************/

with ac as ( -- active customers
select
    md.eom
  , md.year
  , md.month
  , count(distinct ol_active.usercode_aug) as active_customers
from Month_Duration_Table md
  inner join Order_Active_Table ol_active
    on ol_active.orderdate <= md.eom
    and ol_active.orderdate >= md.bom_ly 
group by md.eom, md.year, md.month
order by md.eom asc
), al as ( -- all customers
select
    md.eom
  , md.year
  , md.month
  , count(distinct ol_all.usercode_aug) as all_customers
from Month_Duration_Table md
  inner join Order_Active_Table ol_all
    on ol_all.orderdate <= md.eom
group by md.eom, md.year, md.month
order by md.eom asc
)

select 
    ac.eom
  , ac.year
  , ac.month
  , ac.active_customers
  , al.all_customers
from ac
  inner join al
    on al.eom = ac.eom
order by ac.eom asc