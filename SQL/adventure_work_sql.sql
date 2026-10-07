create database adventure_works;
use adventure_works;

SET SQL_SAFE_UPDATES = 0;

#question 0
create table sales as
select * from fact_internet_sales_new
union all
select * from factinternetsales;

#question1
ALTER TABLE Sales ADD INDEX idx_sales_prod (ProductKey), ADD INDEX idx_sales_cust (CustomerKey);
ALTER TABLE DimProduct ADD INDEX idx_dim_prod (ProductKey);
ALTER TABLE DimCustomer ADD INDEX idx_dim_cust (CustomerKey);

ALTER TABLE Sales ADD COLUMN ProductName VARCHAR(100);
UPDATE Sales s
JOIN DimProduct p ON s.ProductKey = p.ProductKey
SET s.ProductName = p.EnglishProductName;

#question2
ALTER TABLE Sales ADD COLUMN new_unit_price decimal(10,2);
UPDATE Sales s
JOIN DimProduct p ON s.ProductKey = p.ProductKey
SET s.new_unit_price= p.`unit price`;

ALTER TABLE Sales ADD COLUMN customerfullname VARCHAR(100);
UPDATE Sales s
JOIN dimcustomer c ON s.customerkey = c.customerkey 
SET s.customerfullname=CONCAT_WS(' ',
    NULLIF(TRIM(c.FirstName), ''),
    NULLIF(TRIM(c.MiddleName), ''),
    NULLIF(TRIM(c.LastName), '')
);


#question3
CREATE TABLE new_sales AS
WITH ParsedData AS (
    SELECT 
        s.*,
        STR_TO_DATE(s.OrderDateKey, '%Y%m%d') AS DateField
    FROM sales s
)
SELECT 
    p.*,
    YEAR(DateField) AS Year,
    MONTH(DateField) AS MonthNo,
    MONTHNAME(DateField) AS MonthFullName,
    CONCAT('Q', QUARTER(DateField)) AS Quarter,
    DATE_FORMAT(DateField, '%Y-%b') AS YearMonth,
    DAYOFWEEK(DateField) AS WeekdayNo,
    DAYNAME(DateField) AS WeekdayName,
    CASE 
        WHEN MONTH(DateField) >= 7 THEN MONTH(DateField) - 6
        ELSE MONTH(DateField) + 6
    END AS FinancialMonth,
    CONCAT('FQ', CEIL((CASE WHEN MONTH(DateField) >= 7 THEN MONTH(DateField) - 6 ELSE MONTH(DateField) + 6 END) / 3)) AS FinancialQuarter
FROM ParsedData p;


SET SQL_SAFE_UPDATES = 0;

#question4 and question5
ALTER TABLE new_sales
ADD COLUMN SalesAmount_new DECIMAL(12,2),
ADD COLUMN ProductionCost DECIMAL(12,2);

UPDATE new_sales
SET 
    SalesAmount_new = ROUND(UnitPrice * OrderQuantity * (1 - UnitPriceDiscountPct), 2),
    ProductionCost = ROUND(ProductStandardCost * OrderQuantity, 2)
WHERE OrderDateKey IS NOT NULL;

SET SQL_SAFE_UPDATES = 1;

SET SQL_SAFE_UPDATES = 0;


ALTER TABLE new_sales
ADD COLUMN Profit DECIMAL(12,2);
UPDATE new_sales
SET Profit = ROUND(SalesAmount_new - ProductionCost, 2)
WHERE OrderDateKey IS NOT NULL;

SET SQL_SAFE_UPDATES = 1;

#question 7
SELECT 
    MonthNo,
    MonthFullName,
    round(sum(CASE WHEN Year = 2011 THEN SalesAmount ELSE 0 END),2) AS Sales_2011,
    round(SUM(CASE WHEN Year = 2012 THEN SalesAmount ELSE 0 END),2) AS Sales_2012,
    round(SUM(CASE WHEN Year = 2013 THEN SalesAmount ELSE 0 END),2) AS Sales_2013,
    round(SUM(CASE WHEN Year = 2014 THEN SalesAmount ELSE 0 END),2) AS Sales_2014,
    round(SUM(SalesAmount),2) AS TotalSales
FROM new_sales
GROUP BY MonthNo, MonthFullName
ORDER BY MonthNo;

#question8
SELECT 
    Year,
    ROUND(SUM(SalesAmount), 2) AS TotalSales
FROM new_sales
GROUP BY Year
ORDER BY Year;

#Question9 monthwise sale
SELECT 
    MonthNo,
    MonthFullName,
    ROUND(SUM(SalesAmount), 2) AS TotalSales
FROM new_sales
GROUP BY MonthNo, MonthFullName
ORDER BY MonthNo;


#question 10
SELECT 
    quarter,
    ROUND(SUM(SalesAmount), 2) AS TotalSales
FROM new_sales
GROUP BY quarter
ORDER BY quarter;

#Question11 SalesvsCost 
SELECT 
    Year,
    ROUND(SUM(SalesAmount), 2) AS TotalSales,
    ROUND(SUM(ProductionCost), 2) AS TotalCost
FROM new_sales
GROUP BY Year
ORDER BY Year;

#Question12 Sales by Region & Country
SELECT 
    st.SalesTerritoryCountry,
    st.SalesTerritoryRegion,
    ROUND(SUM(SalesAmount), 2) AS TotalSales,
    ROUND(SUM(Profit), 2) AS TotalProfit
FROM new_sales s
left join dimsalesterritory st on st.SalesTerritoryKey=s.SalesTerritoryKey
GROUP BY SalesTerritoryCountry, SalesTerritoryRegion
ORDER BY TotalSales DESC;


#Question13 Business KPIs view

CREATE VIEW v_Important_KPIs AS
SELECT 
    s.Year,
    s.MonthNo,
    s.MonthFullName,
    s.Quarter,
    s.FinancialQuarter,
    st.SalesTerritoryCountry,
    st.SalesTerritoryRegion,
    ROUND(SUM(s.SalesAmount), 2) AS Total_Revenue,
    ROUND(SUM(s.ProductionCost), 2) AS Total_ProductionCost,
    ROUND(SUM(s.Profit), 2) AS Total_Profit,
    SUM(s.OrderQuantity) AS Total_Units_Sold,
    COUNT(DISTINCT s.SalesOrderNumber) AS Total_Orders
FROM new_sales s
join dimsalesterritory st on st.SalesTerritoryKey=s.SalesTerritoryKey
GROUP BY 
    s.Year, 
    s.MonthNo, 
    s.MonthFullName, 
    s.Quarter, 
    s.FinancialQuarter, 
    st.SalesTerritoryCountry, 
    st.SalesTerritoryRegion;
    
    SELECT 
    ROUND(SUM(Total_Revenue), 2) AS Overall_Revenue,
    ROUND(SUM(Total_Profit), 2) AS Overall_Profit,
    ROUND((SUM(Total_Profit) / SUM(Total_Revenue)) * 100, 2) AS Overall_Profit_Margin_Pct,
    SUM(Total_Units_Sold) AS Overall_Units_Sold,
    SUM(Total_Orders) AS Overall_Orders
FROM v_Important_KPIs;
    
    
    SELECT 
    Year,
    ROUND(SUM(SalesAmount), 2) AS Total_Revenue,
    ROUND(SUM(Profit), 2) AS Total_Profit,
    ROUND((SUM(Profit) / NULLIF(SUM(SalesAmount), 0)) * 100, 2) AS Profit_Margin_Pct,
    COUNT(DISTINCT SalesOrderNumber) AS Total_Orders,
    ROUND(SUM(SalesAmount) / NULLIF(COUNT(DISTINCT SalesOrderNumber), 0), 2) AS Average_Order_Value
FROM new_sales
GROUP BY Year
ORDER BY Year;




select * from new_sales;
select * from sales;
show warnings;