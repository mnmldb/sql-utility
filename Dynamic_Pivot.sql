/******************************************************
Dynamic pivot with Transact-SQL (Microsoft SQL Server)
******************************************************/

/******pivot value******/
DECLARE @pivot_value AS NVARCHAR(MAX) = 'Spend_USD'
-- choose one value from below

--'Spend_USD'
--'NetSpend_USD'
--'Spend_GBP'
--'NetSpend_GBP'
--'Orders'
--'NetOrders'

-- clear temporary tables beforehand
IF OBJECT_ID('tempdb..#customers') IS NOT NULL BEGIN DROP TABLE #customers END
IF OBJECT_ID('tempdb..#eom') IS NOT NULL BEGIN DROP TABLE #eom END
IF OBJECT_ID('tempdb..#eom_unique') IS NOT NULL BEGIN DROP TABLE #eom_unique END
IF OBJECT_ID('tempdb..##pivot_jp') IS NOT NULL BEGIN DROP TABLE ##pivot_jp END
IF OBJECT_ID('tempdb..#attribution') IS NOT NULL BEGIN DROP TABLE #attribution END

-- prepare variables to execute dynamic query
DECLARE @cols AS NVARCHAR(MAX) = ''
DECLARE @query AS NVARCHAR(MAX) = ''

--1. all JP customers with latest EOM (end of month) status
SELECT
    ct.UserCode
  , ct.FirstOrderDate
  , ct.FirstOrderDateNet
  , st.EOM
  , st.Status AS LatestStatus_EOM
  , gt.BillingCountry
INTO #customers
FROM Customer_Table ct
  INNER JOIN Status_Table st
    ON st.UserCode = ct.UserCode
    AND st.EOM = (SELECT MAX(EOM) FROM Customer_Table)
  INNER JOIN Geography_Table gt
    ON gt.UserCode = ct.UserCode
WHERE gt.BillingCountry = 'Japan'

--2. spend and orders at each end of month
SELECT
    mt.[End of Month Date] AS EOM
  , cs.UserCode
  , cs.LatestStatus_EOM
  , cs.FirstOrderDate
  , cs.FirstOrderDateNet
  , mt.[Last Order Date] AS LastOrderDate
  , mt.[Last Net Order Date] AS LastOrderDateNet
-- rolling values
  , mt.[Spend Year] AS RollingSpend_GBP
  , mt.[Net Spend Year] AS RollingNetSpend_GBP
  , mt.[Spend Year USD] AS RollingSpend_USD
  , mt.[Net Spend Year USD] AS RollingNetSpend_USD
  , mt.[Orders Year] AS RollingOrders
  , mt.[Net Orders Year] AS RollingNetOrders

-- month values
  , mt.[Spend Month] AS Spend_GBP
  , mt.[Net Spend Month] AS NetSpend_GBP
  , mt.[Spend Month USD] AS Spend_USD
  , mt.[Net Spend Month USD] AS NetSpend_USD
  , mt.[Orders Month] AS Orders
  , mt.[Net Orders Month] AS NetOrders
/*add values if necessary*/


INTO #eom
FROM  mt
  INNER JOIN #customers cs
    ON cs.UserCode = mt.[User Code]

--3. unique list of end of month
SELECT DISTINCT EOM
INTO #eom_unique
FROM #eom


--4. summarize customer attribution
SELECT
    UserCode
  , MIN(FirstOrderDate) AS Min_FirstOrderDate
  , MIN(FirstOrderDateNet) AS Min_FirstOrderDateNet
  , MAX(LastOrderDate) AS Max_LastOrderDate
  , MIN(LastOrderDateNet) AS Max_LastOrderDateNet

  , MAX(RollingNetSpend_USD) AS Max_RollingNetSpend_USD
--  , MAX(RollingNetSpend_GBP) AS Max_RollingNetSpend_GBP
  , CASE
    WHEN MAX(RollingNetSpend_USD) >= 10000 THEN 'Top'
    WHEN MAX(RollingNetSpend_USD) >= 5000  THEN 'Middle'
    WHEN MAX(RollingNetSpend_USD) >= 2500  THEN 'Low'
    WHEN MAX(RollingNetSpend_USD) > 0      THEN 'Entry'
    ELSE 'Other'
    END AS HighestStatus
INTO #attribution
FROM #eom
GROUP BY UserCode

--4. prepare for dynamic query
SELECT @cols = @cols + QUOTENAME(EOM) + ','
FROM #eom_unique
ORDER BY EOM ASC

SELECT @cols = SUBSTRING(@cols, 0, len(@cols)) -- trim "," at end

SET @query =
'SELECT *
 INTO ##pivot_jp
 FROM (SELECT
          EOM
        , UserCode
        , LatestStatus_EOM
        , ' + @pivot_value + '
       FROM #EOM
      ) src
 PIVOT (SUM(' + @pivot_value + ') for EOM in (' + @cols + ')) piv
 ORDER BY UserCode ASC'
-- need to use global temporary table (##) to access outside from dynamic query instance
-- use ' and + to concatenate characters and variables

EXECUTE sp_executesql @query

--5.output
SELECT
    ab.*
  , pv.* -- UserCode column in both tables
FROM ##pivot_jp pv
  INNER JOIN #attribution ab
    ON ab.UserCode = pv.UserCode
ORDER BY ab.UserCode ASC
