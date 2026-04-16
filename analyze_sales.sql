-- analyze_sales.sql
-- Sales performance analysis by region and product category

CREATE TABLE #SalesSummary (
    Region NVARCHAR(50),
    Category NVARCHAR(50),
    TotalRevenue DECIMAL(18,2),
    OrderCount INT,
    AvgOrderValue DECIMAL(18,2)
);

INSERT INTO #SalesSummary
SELECT
    r.RegionName,
    c.CategoryName,
    SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS TotalRevenue,
    COUNT(DISTINCT o.OrderID) AS OrderCount,
    AVG(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS AvgOrderValue
FROM Orders o
INNER JOIN OrderDetails od ON o.OrderID = od.OrderID
INNER JOIN Products p ON od.ProductID = p.ProductID
INNER JOIN Categories c ON p.CategoryID = c.CategoryID
INNER JOIN Customers cu ON o.CustomerID = cu.CustomerID
INNER JOIN Regions r ON cu.RegionID = r.RegionID
WHERE o.OrderDate >= DATEADD(MONTH, -12, GETDATE())
  AND o.Status = 'Completed'
GROUP BY r.RegionName, c.CategoryName;

-- Top 5 regions by revenue
SELECT TOP 5
    Region,
    SUM(TotalRevenue) AS Revenue,
    SUM(OrderCount) AS Orders
FROM #SalesSummary
GROUP BY Region
ORDER BY Revenue DESC;

-- Categories with below-average revenue
SELECT
    Category,
    SUM(TotalRevenue) AS Revenue
FROM #SalesSummary
GROUP BY Category
HAVING SUM(TotalRevenue) < (SELECT AVG(TotalRevenue) FROM #SalesSummary)
ORDER BY Revenue ASC;

DROP TABLE #SalesSummary;
