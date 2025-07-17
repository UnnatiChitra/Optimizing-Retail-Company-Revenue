Create database Sports;

Drop table info;

CREATE TABLE sports.info
(
    product_name VARCHAR(150),
    product_id VARCHAR(11) PRIMARY KEY,
    description VARCHAR(800)
);

DROP TABLE finance;

CREATE TABLE sports.finance
(
    product_id VARCHAR(11) PRIMARY KEY,
    listing_price FLOAT,
    sale_price FLOAT,
    discount FLOAT,
    revenue FLOAT
);

DROP TABLE reviews;

CREATE TABLE sports.reviews
(
    product_id VARCHAR(11) PRIMARY KEY,
    rating FLOAT,
    reviews FLOAT
);

DROP TABLE traffic;

CREATE TABLE sports.traffic
(
    product_id VARCHAR(11) PRIMARY KEY,
    last_visited TIMESTAMP
);

DROP TABLE brands;

CREATE TABLE sports.brands
(
    product_id VARCHAR(11) PRIMARY KEY,
    brand VARCHAR(7)
);brands

\copy info FROM 'info.csv' DELIMITER ',' CSV HEADER;
\copy finance FROM 'finance.csv' DELIMITER ',' CSV HEADER;
\copy reviews FROM 'reviews_v2.csv' DELIMITER ',' CSV HEADER;
\copy traffic FROM 'traffic_v3.csv' DELIMITER ',' CSV HEADER;
\copy brands FROM 'brands_v2.csv' DELIMITER ',' CSV HEADER;

-- 1. Counting missing values
SELECT 
    COUNT(*) AS total_rows,
    COUNT(i.description) AS count_description,
    COUNT(f.listing_price) AS count_listing_price,
    COUNT(t.last_visited) AS count_last_visited,
    COUNT(b.brand) AS count_brand
FROM
    sports.info i
        JOIN
    sports.finance f ON i.product_id = f.product_id
        JOIN
    sports.traffic t ON i.product_id = t.product_id
        JOIN
    sports.brands b ON i.product_id = b.product_id;

-- 2. Nike vs Adidas pricing
SELECT b.brand, 
       listing_price, 
       COUNT(f.*) as count
FROM brands b
JOIN finance f
ON b.product_id = f.product_id
WHERE f.listing_price > 0
GROUP BY b.brand, listing_price
ORDER BY listing_price DESC;

-- 3. Labeling price ranges
SELECT 
    b.brand,
    COUNT(*) AS row_count,
    SUM(f.revenue) AS total_revenue,
    CASE
        WHEN f.listing_price < 42 THEN 'Budget'
        WHEN f.listing_price < 74 THEN 'Average'
        WHEN f.listing_price < 129 THEN 'Expensive'
        ELSE 'Elite'
    END AS price_category
FROM
    sports.brands AS b
        JOIN
    sports.finance AS f ON b.product_id = f.product_id
WHERE
    b.brand IS NOT NULL
GROUP BY b.brand , CASE
    WHEN f.listing_price < 42 THEN 'Budget'
    WHEN f.listing_price < 74 THEN 'Average'
    WHEN f.listing_price < 129 THEN 'Expensive'
    ELSE 'Elite'
END
ORDER BY total_revenue DESC;

-- 4.Total revenue of Adidas and Nike.
SELECT 
    SUM(f.revenue) AS total_revenue, b.brand
FROM
    sports.finance f
        LEFT JOIN
    sports.brands b ON f.product_id = b.product_id
GROUP BY b.brand
ORDER BY total_revenue DESC;

-- 5. Average discount by brand
SELECT 
    b.brand, AVG(discount) * 100 AS average_discount
FROM
    brands b
        JOIN
    finance f ON b.product_id = f.product_id
WHERE
    b.brand IS NOT NULL
GROUP BY b.brand;

-- 6. Comparing listing vs sale prices.
SELECT 
    b.brand,
    AVG(f.discount) AS avg_discount,
    AVG((f.listing_price - f.sale_price) / f.listing_price) AS avg_calc_markdown,
    SUM(f.revenue) AS total_revenue
FROM
    sports.brands b
        JOIN
    sports.finance f ON f.product_id = b.product_id
GROUP BY b.brand
ORDER BY avg_discount DESC;

-- 7. Top Revenue Generated Products with Brands
WITH highest_revenue_product AS
(  
   SELECT i.product_name,
          b.brand,
          revenue
   FROM finance f
   JOIN sports.info i
   ON f.product_id = i.product_id
   JOIN sports.brands b
   ON b.product_id = i.product_id
   WHERE product_name IS NOT NULL 
     AND revenue IS NOT NULL 
     AND brand IS NOT NULL
)
SELECT product_name,
       brand,
       revenue,
        RANK() OVER (ORDER BY revenue DESC) AS product_rank
FROM highest_revenue_product
LIMIT 10;

-- 8. Do higher ratings correlate with higher revenue?
SELECT 
    b.brand,
    i.product_name,
    SUM(f.revenue) AS total_revenue,
    AVG(r.rating) AS avg_rating,
    COUNT(r.rating) AS total_rating
FROM
    sports.finance f
        JOIN
    sports.reviews r ON f.product_id = r.product_id
        JOIN
    sports.brands b ON f.product_id = b.product_id
        JOIN
    sports.info i ON f.product_id = i.product_id
GROUP BY b.brand , i.product_name
ORDER BY SUM(f.revenue) DESC;

-- 9. Creating view so that downstream reports become easy.
CREATE OR REPLACE VIEW vw_product_metrics AS
    SELECT 
        i.product_id,
        i.product_name,
        b.brand,
        f.listing_price,
        f.sale_price,
        f.discount,
        f.revenue,
        r.rating,
        r.reviews AS review_count,
        MAX(t.last_visited) AS last_seen,
        COUNT(t.product_id) AS visit_count
    FROM
        sports.info i
            LEFT JOIN
        sports.brands b ON b.product_id = i.product_id
            LEFT JOIN
        sports.finance f ON f.product_id = i.product_id
            LEFT JOIN
        sports.reviews r ON r.product_id = i.product_id
            LEFT JOIN
        sports.traffic t ON t.product_id = i.product_id
    GROUP BY i.product_id , i.product_name , b.brand , f.listing_price , f.sale_price , f.discount , f.revenue , r.rating , r.reviews;

-- 10. Checking for error in pricing.
SELECT 
    *
FROM
    sports.finance
WHERE
    sale_price > listing_price;

-- 11. Products haven’t been viewed recently.
SELECT 
    product_id, product_name, brand, last_seen
FROM
    vw_product_metrics
WHERE
    last_seen IS NULL
        OR last_seen < NOW() - INTERVAL 30 DAY
ORDER BY last_seen ASC

