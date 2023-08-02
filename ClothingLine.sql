--Let's create a table with product level information for all the transactions made for Balanced Tree in a particular month (e.g. January of 2021)
CREATE TEMP TABLE sales_monthly AS
(SELECT *
FROM balanced_tree.sales
WHERE EXTRACT(MONTH FROM start_txn_time) = 1 AND EXTRACT(YEAR FROM start_txn_time) = 2021);


-- what was the total quantity sold?
SELECT SUM (qty) AS "Total Quantity" FROM balanced_tree.sales;

-- What is the total generated revenue for all products before discounts?
SELECT sum(qty * price) AS Revenue
FROM balanced_tree.sales

-- What was the total discount amount for all products?
SELECT round(SUM (qty * price * discount::numeric/100),2) AS "Total Discount"
FROM balanced_tree.sales;

-- How many unique transactions were there?
SELECT COUNT(DISTINCT(txn_id )) AS "Unique Transactions"
FROM balanced_tree.sales;

-- What is the average unique products purchased in each transaction?
SELECT round(AVG("UniqueProducts"),3) AS "AverageUniqueProducts"
FROM (
	SELECT txn_id, COUNT (DISTINCT prod_id) AS "UniqueProducts"
	FROM balanced_tree.sales
	GROUP BY txn_id) AS subquery;
	
-- What is the average discount value per transaction?
WITH t AS
(SELECT txn_id,
        SUM(qty * price * discount::numeric/100) AS txn_discount
 FROM balanced_tree.sales
 GROUP BY 1)

SELECT ROUND(AVG(txn_discount), 2) AS avg_txn_discount
FROM t;


-- What are the 25th, 50th and 75th percentile values for the revenue per transaction
SELECT
  PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Revenue) AS Percentile25,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Revenue) AS percentil50,
  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Revenue) AS Percentile75
FROM (
  SELECT txn_id, SUM(qty * price) AS Revenue
  FROM balanced_tree.sales
  GROUP BY txn_id
) AS subquery;

-- What is the percentage split of all transactions for members vs non-members
SELECT
  sa.countOfTransactions,
  sa.member,
  ta.overall_total,
  (sa.countOfTransactions::float / ta.overall_total) * 100 AS Percentage
FROM
	(SELECT
    count(txn_id) AS overall_total
    FROM
     balanced_tree.sales 
  ) AS ta,
    (SELECT
      member,
      count(txn_id) AS countOfTransactions
    FROM
      balanced_tree.sales
    GROUP BY
      member
  ) AS sa;
-- What is the average revenue for member transactions and non-member transactions?
select round(avg(Revenue),3),member from
(SELECT member,txn_id, SUM(qty * price) AS Revenue
FROM balanced_tree.sales
GROUP BY txn_id,member
) AS subquery
group by member;

SELECT member,
       SUM(qty * price) AS total_revenue_before_discounts 
FROM balanced_tree.sales
GROUP BY 1

-- What are the top 3 products by total revenue before discount
SELECT prod_id,SUM(Revenue) AS TotalRevenue
FROM (
    SELECT prod_id, (qty * price) AS Revenue
    FROM balanced_tree.sales
    GROUP BY prod_id, qty, price
) AS subquery
group by prod_id
order by TotalRevenue desc
limit 3;

-- What is the total quantity, revenue and discount for each segment
Select pd.segment_id,sum(sal.qty) as "total quantity",sum(sal.qty*sal.price) as Revenue,sum(sal.discount) as "total Discount"
from balanced_tree.sales sal
join balanced_tree.product_details pd on sal.prod_id = pd.product_id
group by pd.segment_id;

-- What is the top selling product for each segment
select product_id,segment_id,max("count of Transactions") from
(Select pd.product_name,pd.product_id,count(sal.txn_id) as "count of Transactions",pd.segment_id
from balanced_tree.sales sal
join balanced_tree.product_details pd on sal.prod_id = pd.product_id
group by pd.segment_id,pd.product_id,pd.product_name
order by "count of Transactions" desc) as subquery
group by segment_id,product_id
limit 1;
-- What is the total quantity, revenue and discount for each category
Select pd.category_id,sum(sal.qty) as "total quantity",sum(sal.qty*sal.price) as Revenue,sum(sal.discount) as "total Discount"
from balanced_tree.sales sal
join balanced_tree.product_details pd on sal.prod_id = pd.product_id
group by pd.category_id;
 
 -- What is the top selling product for each category
Select count(sal.txn_id) as "count of Transactions",pd.product_id,pd.segment_id
from balanced_tree.sales sal
join balanced_tree.product_details pd on sal.prod_id = pd.product_id
group by pd.product_id,pd.segment_id
order by "count of Transactions" desc;


SELECT pd.segment_id, pd.product_id, pd.product_name, subquery.total_sold
FROM balanced_tree.product_details pd
JOIN (
  SELECT s.prod_id, SUM(s.qty) AS total_sold
  FROM balanced_tree.sales s
  GROUP BY s.prod_id
) subquery ON pd.product_id = subquery.prod_id
JOIN (
  SELECT pd.segment_id, MAX(subquery.total_sold) AS max_sold
  FROM balanced_tree.product_details pd
  JOIN (
    SELECT s.prod_id, SUM(s.qty) AS total_sold
    FROM balanced_tree.sales s
    GROUP BY s.prod_id
  ) subquery ON pd.product_id = subquery.prod_id
  GROUP BY pd.segment_id
) max_sold_per_segment ON pd.segment_id = max_sold_per_segment.segment_id AND subquery.total_sold = max_sold_per_segment.max_sold
ORDER BY pd.segment_id;

-- What is the percentage split of revenue by product for each segment
SELECT
  rev.segment_id,
  Ot.overall_total,
  Round((rev.revenue::float / Ot.overall_total) * 100) AS Percentage
FROM
	(SELECT
    SUM(qty * price) AS overall_total
    FROM
     balanced_tree.sales 
  ) AS Ot,
	(SELECT SUM(sal.qty * sal.price) AS revenue, pd.segment_id
	FROM balanced_tree.sales sal
	JOIN balanced_tree.product_details pd ON sal.prod_id = pd.product_id
	GROUP BY pd.segment_id) as rev;
-- what is the percentage split of revenue by segment for each category
WITH t AS
(SELECT category_id,
        category_name,
        segment_id,
        segment_name,
        SUM(qty * s.price) AS total_revenue_before_discounts
FROM balanced_tree.sales s
LEFT JOIN balanced_tree.product_details p ON s.prod_id = p.product_id
GROUP BY 1, 2, 3, 4)

SELECT *,
       ROUND(100*total_revenue_before_discounts / (SUM(total_revenue_before_discounts) OVER (PARTITION BY category_id)), 2) AS revenue_percentage
FROM t
ORDER BY category_id, revenue_percentage DESC;
	
-- What is the percentage split of total revenue by category
SELECT
	category_id,
  rev,
  Ot.overall_total,
  Round((rev.revenue::float / Ot.overall_total) * 100) AS Percentage
FROM
	(SELECT
    SUM(qty * price) AS overall_total
    FROM
     balanced_tree.sales 
  ) AS Ot,
	(SELECT SUM(sal.qty * sal.price) AS revenue, pd.category_id
	FROM balanced_tree.sales sal
	JOIN balanced_tree.product_details pd ON sal.prod_id = pd.product_id
	GROUP BY pd.category_id) as rev;

-- What is the total transaction “penetration” for each product? (hint: penetration = number of transactions where at least 1 quantity of a product was purchased divided by total number of transactions)
SELECT 
	Tt.product_id,
    (Tt.countofTransaction::float / Ot.overall_total) AS "Total Penetration"
FROM
	(SELECT
    count(txn_id) AS overall_total
    FROM
     balanced_tree.sales 
  ) AS Ot,
	(SELECT COUNT(txn_id) AS countofTransaction,product_id
    FROM balanced_tree.sales
	JOIN balanced_tree.product_details
	ON sales.prod_id = product_details.product_id
    where qty > 0
	Group BY product_id) AS Tt;
	
SELECT prod_id,
       product_name,
       ROUND(COUNT(txn_id)::numeric / (SELECT COUNT(DISTINCT txn_id) 
                                       FROM balanced_tree.sales), 3) AS txn_penetration
FROM balanced_tree.sales s
LEFT JOIN balanced_tree.product_details p ON s.prod_id = p.product_id
GROUP BY 1, 2

	
SELECT prod_id,
       product_name,
       (SELECT COUNT(DISTINCT txn_id) FROM balanced_tree.sales), 3 AS txn_penetration
FROM balanced_tree.sales s
LEFT JOIN balanced_tree.product_details p ON s.prod_id = p.product_id
Group by 1, 2

-- What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?
SELECT s.prod_id, t1.prod_id, t2.prod_id, COUNT(*) AS combination_cnt       
FROM balanced_tree.sales s
JOIN balanced_tree.sales t1 ON t1.txn_id = s.txn_id 
AND s.prod_id < t1.prod_id
JOIN balanced_tree.sales t2 ON t2.txn_id = s.txn_id
AND t1.prod_id < t2.prod_id
GROUP BY 1, 2, 3
ORDER BY 4 DESC
LIMIT 1

