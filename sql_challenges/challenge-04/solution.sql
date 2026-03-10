-- Return a list of all the colours in the two tables. Each colour must only appear once

select distinct * from (
    select colour from my_brick_collection
    union all
    select colour from your_brick_collection
    order by colour
);

-- Return a list of all the shapes in both tables. There must show one row for each row in the source tables

select shape from my_brick_collection
union all
select shape from your_brick_collection
order  by shape;

-- Return a list of all the shapes in my collection not in yours

select shape from my_brick_collection
minus
select shape from your_brick_collection;

-- Return a list of all the colours that are in both tables

select colour from my_brick_collection
intersect
select colour from your_brick_collection
order  by colour;


