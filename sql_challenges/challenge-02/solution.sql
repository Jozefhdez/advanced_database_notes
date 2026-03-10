-- SECTION 6

-- 1. Find the domestic and international sales for each movie
SELECT * FROM movies AS m
LEFT JOIN boxoffice AS b
ON m.id = b.movie_id;

-- 2. Show the sales numbers for each movie that did better internationally rather than domestically
SELECT * FROM movies AS m
LEFT JOIN boxoffice AS b
ON m.id = b.movie_id
WHERE international_sales > domestic_sales;

-- 3. List all the movies by their ratings in descending order
SELECT title, rating FROM movies AS m
JOIN boxoffice AS b
ON m.id = b.movie_id
ORDER BY rating DESC;

-- SECTION 7

-- 1. Find the list of all buildings that have employees
SELECT DISTINCT building_name
FROM buildings b
INNER JOIN employees e
ON e.building = b.building_name;

-- 2. Find the list of all buildings and their capacity
SELECT * FROM buildings;

-- 3. List all buildings and the distinct employee roles in each building (including empty buildings)
SELECT DISTINCT building_name, role FROM buildings b
LEFT JOIN employees e
ON b.building_name = e.building;

-- Interview question
SELECT p.page_id FROM pages p
LEFT JOIN page_likes pl
ON p.page_id = pl.page_id
WHERE pl.page_id IS NULL;