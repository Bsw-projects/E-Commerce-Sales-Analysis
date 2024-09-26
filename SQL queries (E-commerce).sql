SELECT COUNT(*)
FROM dbo.Sales_Transaction;

-- Find total number of products and make sure the number of Product number and Product name matches
SELECT 
     COUNT(DISTINCT Productno) AS DistinctProductnoCount
    ,COUNT(DISTINCT ProductName) AS DistinctProductNameCount
FROM dbo.Sales_Transaction;

SELECT DISTINCT Country
FROM dbo.Sales_Transaction;

-- Ensure clarity and simplicity of terms
UPDATE dbo.Sales_Transaction
SET Country = 
	CASE
		WHEN Country = 'EIRE' THEN 'Ireland'
		WHEN Country = 'USA' THEN 'United States'
		WHEN Country = 'RSA' THEN 'South Africa'
		WHEN Country = 'European Community' THEN 'European Country (Unspecified)'
		ELSE Country  -- Keeps the existing value 
	END;

-- Identify NULL in each columns
SELECT	
	 SUM(CASE WHEN TransactionNo IS NULL THEN 1 ELSE 0 END) AS TransactionNo_Null_Count
	,SUM(CASE WHEN Date IS NULL THEN 1 ELSE 0 END) AS Date_Null_Count
	,SUM(CASE WHEN ProductNo IS NULL THEN 1 ELSE 0 END) AS ProductNo_Null_Count
	,SUM(CASE WHEN ProductName IS NULL THEN 1 ELSE 0 END) AS ProductName_Null_Count
    ,SUM(CASE WHEN Price IS NULL THEN 1 ELSE 0 END) AS Price_Null_Count
	,SUM(CASE WHEN Quantity IS NULL THEN 1 ELSE 0 END) AS Quantity_Null_Count
	,SUM(CASE WHEN CustomerNo IS NULL THEN 1 ELSE 0 END) AS CustomerNo_Null_Count
FROM dbo.Sales_Transaction;
 -- no null value found

-- Check for non-numeric characters in columns that should be numeric
SELECT DISTINCT 
		 TransactionNo
		,Price
		,Quantity
		,CustomerNo
FROM dbo.Sales_Transaction
WHERE CustomerNo LIKE '%[^0-9]%';
-- Note:
-- "C" in the TransactionNo indicates a cancellation, which resulted in 'NA' in CustomerNo
-- All cancellation were from products out of stock (quanity negative) 

-- Export details of canceled orders to analyze the amount lost from stock shortage
SELECT 
	 Date
	,ProductNo
	,ProductName
	,Country
	,SUM(CAST(Quantity AS INT)) AS TotalOrderLost
	,SUM(Price * CAST(Quantity AS INT)) AS TotalLostValue
FROM Sales_Transaction
WHERE Quantity < 0
GROUP BY Date,ProductNo,ProductName,Country
ORDER BY Date ASC;

-- Archive order cancellation data so that it doesn't impact other analysis
CREATE TABLE Archived_Order_Cancellations 
(
     Date DATE
	,ProductNo VARCHAR(50)
	,ProductName VARCHAR(100)
	,Country VARCHAR(50)
	,TotalLostAmount DECIMAL(20, 4)
);

-- Insert cancellation order data into the archive table
INSERT INTO Archived_Order_Cancellations (Date, ProductNo, ProductName, Country, TotalLostAmount)
SELECT 
     Date
	,ProductNo
	,ProductName
	,Country
	,SUM(CAST(Quantity AS INT)) AS TotalOrderLost
	,SUM(Price * CAST(Quantity AS INT)) AS TotalLostValue
FROM Sales_Transaction
WHERE Quantity < 0;

-- Delete the archived data from the original table
DELETE FROM Sales_Transaction
WHERE Quantity < 0;

-- Verify table
SELECT * FROM Archived_Order_Cancellations;




-- Idenitfy duplicates
WITH duplicate_cte AS
 (
 SELECT *,
 ROW_NUMBER() OVER 
	(PARTITION BY TransactionNo, Date, ProductNo, ProductName, 
				  Price, Quantity, CustomerNo, Country
	 ORDER BY TransactionNo  
	 ) AS row_num
FROM dbo.Sales_Transaction
 )
SELECT *
FROM duplicate_cte
WHERE row_num > 1;

-- Check for the cause of duplicates
SELECT *
FROM Sales_Transaction
WHERE CustomerNo = '14649' AND TransactionNo = '580635';
-- Note: 
-- Customers has the same TransactionNo for all of their orders made on the same day.
-- Therefore, cannot remove orders identified as duplicates, 
-- as multiple transactions with the same TransactionNo do not necessarily indicate duplicates.

-- Check total products and quantities ordered by each customer per day
SELECT 
     CustomerNo
	,Date AS OrderDate
	,COUNT(ProductNo) AS TotalProducts -- Count of distinct products ordered
	,SUM(CAST(Quantity AS INT)) AS TotalQuantity  -- Currently it's VARCHAR so need to be converted to INT to use SUM function 
FROM dbo.Sales_Transaction
GROUP BY CustomerNo, Date  
ORDER BY OrderDate, CustomerNo;  

SELECT *
FROM Sales_Transaction;

-- Segment and export customer type for analysis: Direct customers & Retail
SELECT 
	 Date
	,ProductNo
	,ProductName
    ,CustomerNo
	,SUM(CAST(Quantity AS INT)) AS TotalOrderPerDay
	,SUM(CAST(Quantity AS INT) * Price) AS TotalPricePaidPerDay
	,CASE 
		WHEN SUM(CAST(Quantity AS INT)) <= 50 THEN 'Direct'
	    ELSE 'Retail'
	 END AS CustomerType -- Segment based on total order quantity per day (if has over 50 orders per day, considered retail)
	,Country
FROM dbo.Sales_Transaction
GROUP BY Date, ProductNo, ProductName, CustomerNo, Country
ORDER BY Date;

-- Export final table 
SELECT 
            Date
	,ProductName
	,CustomerNo
	,COUNT(DISTINCT TransactionNo) AS NumberOfOrders
	,COUNT(DISTINCT CustomerNo) AS TotalCustomers
	,SUM(CAST(Quantity AS INT) * Price) AS TotalRevenue -- total rev for each product for all unique transactions on that date, separately for each country
	,CASE 
        WHEN SUM(CAST(Quantity AS INT)) <= 50 THEN 'Direct' ELSE 'Retail'
     END AS CustomerType
	,Country
FROM dbo.Sales_Transaction
GROUP BY 
	 Date
	,ProductName
	,CustomerNo
	,Country
ORDER BY Date ASC;  
