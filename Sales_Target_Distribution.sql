/******************************************************
Sales Target Distribution with Google BigQuery
******************************************************/

select
    td.fulldate
  , td.year
  , td.month
  , td.day
  -- , td.target_distribution
  , tg.storekey
  , tg.forecast
  -- , tg.gtv_target
  , tg.gtv_target * td.target_distribution as gtv_daily_target

from Target_Distbribution_Table td
  cross join Target_Month_Table tg 

where td.month = tg.month

-- order by td.fulldate asc, rfc.storekey asc
