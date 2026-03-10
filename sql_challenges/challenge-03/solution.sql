-- SECTION 10

-- 1. Find the longest time that an employee has been at the studio.
SELECT MAX(years_employed) FROM employees;

-- 2. For each role, find the average number of years employed by employees in that role
SELECT role, AVG(years_employed) FROM employees
GROUP BY role;

-- 3. Find the total number of employee years worked in each building
SELECT building, SUM(years_employed) FROM employees
GROUP BY building;

-- SECTION 11

-- 1. Find the number of Artists in the studio (without a HAVING clause)
SELECT COUNT(*) FROM employees
WHERE role = "Artist";

-- 2. Find the number of Employees of each role in the studio
SELECT role, COUNT(*) FROM employees
GROUP BY role;

-- 3. Find the total number of years employed by all Engineers
SELECT SUM(years_employed) FROM employees
WHERE role = "Engineer";

-- FreeSQL

-- 1: Number of different shapes, the standard deviation (stddev) of the unique weights
select count(distinct shape) number_of_shapes,
       stddev(distinct weight) distinct_weight_stddev
from   bricks;

-- 2: Return the total weight for each shape stored in the bricks table
select shape, sum(weight) shape_weight
from   bricks
group by shape;

-- 3: Find the shapes which have a total weight less than four
select shape, sum(weight) as total_weight
from   bricks
group  by shape
having sum(weight) < 4;