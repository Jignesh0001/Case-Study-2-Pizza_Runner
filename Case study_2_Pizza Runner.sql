						  -- Data cleaning --		
-- 1. customer_orders
update customer_orders set exclusions = replace(exclusions,'null','');
update customer_orders set exclusions = '' where exclusions is null; 
update customer_orders set extras = replace(extras,'null','');
update customer_orders set extras = '' where extras is null; 

-- 2. runner_orders
update runner_orders set pickup_time = replace(pickup_time,'null','');
update runner_orders set distance = replace(distance,'null','');
update runner_orders set duration = replace(duration,'null','');
update runner_orders set cancellation = replace(cancellation,'null','');
update runner_orders set cancellation = '' where cancellation is null; 
update runner_orders set duration = TRIM('mins' from duration);
update runner_orders set duration = TRIM('minute' from duration);
update runner_orders set duration = TRIM('minutes' from duration);
update runner_orders set distance = TRIM('km' from distance);

                                -- A. Pizza Metrics --
-- 1. How many pizzas were ordered?
select count(order_id) from customer_orders;

-- 2. How many unique customer orders were made?
select count(distinct(order_id)) from customer_orders;

-- 3. How many successful orders were delivered by each runner?
select runner_id, count(order_id) as succesfull_orders from runner_orders
where distance not like ""
group by runner_id;

-- 4. How many of each type of pizza was delivered?
select pizza_name, count(order_id) from customer_orders
join runner_orders using(order_id)
join pizza_names using (pizza_id)
where duration not like ""
group by pizza_name;

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?
select pizza_name, customer_id, count(a.pizza_id) as count from customer_orders a
join pizza_names using(pizza_id)
group by pizza_name,customer_id;

-- 6. What was the maximum number of pizzas delivered in a single order?
select count(order_id) as Order_count from customer_orders
group by order_id
order by order_count desc
limit 1;

-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
select customer_id,
sum(case when (exclusions not like "") or (extras not like "") then 1 else 0 end)
  as Changes_made,
sum(case when (exclusions like "") and (extras like "") then 1 else 0 end) as No_Changes
from customer_orders
join runner_orders using (order_id)
where duration not like ""
group by customer_id;

-- 8. How many pizzas were delivered that had both exclusions and extras?
select 
sum(case  when (exclusions not like '') and (extras not like '') then 1 else 0 end) 
as Total_del_with_changes
from customer_orders
join runner_orders using (order_id)
where duration not like '';

-- 9. What was the total volume of pizzas ordered for each hour of the day?
select hour(order_time) as Order_hour, count(hour(order_time)) as Volume
from customer_orders
group by order_hour;

-- 10. What was the volume of orders for each day of the week?
select dayname(order_time) as Day_name, count(dayname(order_time)) as Volume
from customer_orders
group by Day_name;

						-- B. Runner and Customer Experience --
-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
select week(registration_date, 1) as week_num, count(runner_id) from runners
group by 1;

-- 2. What was the average time in minutes it took for each runner to arrive at
-- the Pizza Runner HQ to pickup the order?
select runner_id, round(avg(minute(timediff(pickup_time,order_time))),2) as Time_to_pickup 
from runner_orders a
join customer_orders using(order_id)
where duration not like ""
group by runner_id;

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
with CTE as
(select a.order_id, minute(timediff(pickup_time,order_time)) as Time_to_prepare, 
count(a.order_id) as Pizza_count from runner_orders
join customer_orders a using(order_id)
where duration not like ""
group by a.order_id,Time_to_prepare)
select pizza_count, avg(Time_to_prepare) from CTE
group by pizza_count;

-- 4. What was the average distance travelled for each customer?
select customer_id, round(avg(distance),2) as avg_Distance_in_KM
from customer_orders
join runner_orders using(order_id)
where duration not like ""
group by customer_id;

-- 5. What was the difference between the longest and shortest delivery times for all orders?
With CTE as
(select order_id, duration as Time_in_min from customer_orders
join runner_orders using(order_id)
where duration not like "")
select concat(max(Time_in_min)-min(Time_in_min), " Min") as Difference from CTE;

-- 6. What was the average speed for each runner for each delivery and do you notice any
-- trend for these values?
select order_id, runner_id, round(avg(distance*60/duration),2) as Avg_Time_in_min from runner_orders
where duration not like ""
group by order_id, runner_id;


-- 7. What is the successful delivery percentage for each runner?
select runner_id, round(100*sum(case when duration not like "" then 1 else 0 end)/count(*) ,0) 
as Succesful_Delivery_Pct from runner_orders
group by runner_id;


						-- C. Ingredient Optimisation --
-- 1. What are the standard ingredients for each pizza?

WITH RECURSIVE cte AS (
  SELECT
    pizza_id,
    SUBSTRING_INDEX(toppings, ',', 1) AS topping,
    SUBSTRING(toppings, LENGTH(SUBSTRING_INDEX(toppings, ',', 1)) + 2) AS remaining_toppings
  FROM
    pizza_recipes
  UNION ALL
  SELECT
    pizza_id,
    SUBSTRING_INDEX(remaining_toppings, ',', 1) AS topping,
    SUBSTRING(remaining_toppings, LENGTH(SUBSTRING_INDEX(remaining_toppings, ',', 1)) + 2) 
    AS remaining_toppings
  FROM
    cte
  WHERE
    remaining_toppings != ''
)
SELECT DISTINCT pizza_id, group_concat(topping_name) FROM cte
join pizza_toppings on topping = topping_id
group by pizza_id
ORDER BY pizza_id;

				-- OR --
SELECT DISTINCT pizza_id, group_concat(topping_name)
FROM pizza_recipes
RIGHT JOIN
pizza_toppings ON FIND_IN_SET(topping_id, REPLACE(toppings,' ', '')) > 0
group by pizza_id;
  
-- 2. What was the most commonly added extra?
WITH RECURSIVE cte AS (
  SELECT
    SUBSTRING_INDEX(extras, ',', 1) AS Added_Extras,
    SUBSTRING(extras, LENGTH(SUBSTRING_INDEX(extras, ',', 1)) + 2) AS Extras_2
  FROM
    customer_orders
  UNION ALL
  SELECT
    SUBSTRING_INDEX(Extras_2, ',', 1) AS Added_Extras,
    SUBSTRING(Extras_2, LENGTH(SUBSTRING_INDEX(Extras_2, ',', 1)) + 2) 
    AS Extras_2
  FROM
    cte
  WHERE
    Extras_2 != ''
)
select distinct trim(Added_Extras), topping_name from CTE
join pizza_toppings on Added_Extras = topping_id
where Added_Extras != '';

-- 3. What was the most common exclusion?
WITH RECURSIVE cte AS (
  SELECT
    SUBSTRING_INDEX(exclusions, ',', 1) AS Common_exclusion,
    SUBSTRING(exclusions, LENGTH(SUBSTRING_INDEX(exclusions, ',', 1)) + 2) AS Exclusion_2
  FROM
    customer_orders
  UNION ALL
  SELECT
    SUBSTRING_INDEX(Exclusion_2, ',', 1) AS Common_exclusion,
    SUBSTRING(Exclusion_2, LENGTH(SUBSTRING_INDEX(Exclusion_2, ',', 1)) + 2) 
    AS Exclusion_2
  FROM
    cte
  WHERE
    Exclusion_2 != ''
)
select distinct trim(Common_exclusion), topping_name from CTE
join pizza_toppings on Common_exclusion = topping_id
where Common_exclusion != '';

-- 4. Generate an order item for each record in the customers_orders table in the 
      -- format of one of the following:
							-- Meat Lovers
select order_id, customer_id, pizza_id, pizza_name from customer_orders
join pizza_names using (pizza_id)
where pizza_name like '%Meatlovers%' ;
    
						-- Meat Lovers - Exclude Beef
Select Distinct customer_id,order_id, topping_name as excluded_toppings FROM customer_orders
Right Join
pizza_toppings ON FIND_IN_SET(topping_id, REPLACE(exclusions,' ', '')) > 0
where customer_id is not null and pizza_id = 1 and  topping_name like '%Beef%';

						-- Meat Lovers - Extra Bacon
Select Distinct customer_id,order_id, topping_name as Extra_toppings FROM customer_orders
Right Join
pizza_toppings ON FIND_IN_SET(topping_id, REPLACE(extras,' ', '')) > 0
where customer_id is not null and pizza_id = 1 and topping_name like '%Bacon%';

				-- Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
Select Distinct customer_id,order_id, a.topping_name as extras,  b.topping_name as exclusions FROM customer_orders
right Join
pizza_toppings b ON FIND_IN_SET(b.topping_id, REPLACE(exclusions,' ', '')) > 0
Right Join
pizza_toppings a ON FIND_IN_SET(a.topping_id, REPLACE(extras,' ', '')) > 0
where customer_id is not null and pizza_id = 1 and a.topping_name in ('%Mushroom%','%Peppers%') 
and b.topping_name in ('%Cheese%', '%Bacon%');

-- 5. Generate an alphabetically ordered comma separated ingredient list for each pizza order 
	-- from the customer_orders table and add a 2x in front of any relevant ingredients
	-- For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"
(select a.order_id, a.pizza_id, concat('2x', group_concat(b.topping_name)) As Toppings
from customer_orders a
join 
(SELECT DISTINCT pizza_id, topping_name
FROM pizza_recipes
RIGHT JOIN
pizza_toppings ON FIND_IN_SET(topping_id, REPLACE(toppings,' ', '')) > 0) b using (pizza_id)
where Exclusions = '' and Extras = ''
group by a.order_id, a.pizza_id)
Union
(with CTE AS
(select a.order_id, a.pizza_id, b.topping_name, excluded_toppings, Extra_toppings from customer_orders a
join 
(SELECT DISTINCT pizza_id, topping_id, topping_name
FROM pizza_recipes
RIGHT JOIN
pizza_toppings ON FIND_IN_SET(topping_id, REPLACE(toppings,' ', '')) > 0) b on a.pizza_id = b.pizza_id
and (Exclusions != '' or Extras != '')
left join
(Select Distinct customer_id,order_id, topping_id, topping_name as excluded_toppings FROM customer_orders
Right Join
pizza_toppings ON FIND_IN_SET(topping_id, REPLACE(exclusions,' ', '')) > 0
where customer_id is not null) c on a.order_id = c.order_id 
and b.Topping_name = c.excluded_toppings
left join
(Select Distinct customer_id,order_id, topping_id, topping_name as Extra_toppings FROM customer_orders
Right Join
pizza_toppings ON FIND_IN_SET(topping_id, REPLACE(extras,' ', '')) > 0
where customer_id is not null) d on a.order_id = d.order_id 
and b.Topping_name = d.Extra_toppings)
select distinct(order_id), pizza_id, concat('2x',group_concat(distinct(topping_name))) As Toppings
from CTE
where excluded_toppings is null and Extra_toppings is null
group by order_id, pizza_id, excluded_toppings, Extra_toppings);
    
-- 6. What is the total quantity of each ingredient used in all delivered pizzas sorted by 
   -- most frequent first?
With CTE As
((select a.order_id, a.pizza_id, b.topping_id, null as excluded_toppings, null as Extra_toppings 
from customer_orders a
join 
(SELECT DISTINCT pizza_id, topping_id
FROM pizza_recipes
RIGHT JOIN
pizza_toppings ON FIND_IN_SET(topping_id, REPLACE(toppings,' ', '')) > 0) b using (pizza_id)
join runner_orders using (order_id)
where Exclusions = '' and Extras = ''  and cancellation = '')
Union ALL
(select a.order_id, a.pizza_id, b.topping_id, excluded_toppings, Extra_toppings from customer_orders a
join 
runner_orders using (order_id)
join 
(SELECT DISTINCT pizza_id, topping_id
FROM pizza_recipes
RIGHT JOIN
pizza_toppings ON FIND_IN_SET(topping_id, REPLACE(toppings,' ', '')) > 0) b on a.pizza_id = b.pizza_id
and (Exclusions != '' or Extras != '') and cancellation = ''
left join
(Select Distinct customer_id,order_id, topping_id as excluded_toppings FROM customer_orders
Right Join
pizza_toppings ON FIND_IN_SET(topping_id, REPLACE(exclusions,' ', '')) > 0
where customer_id is not null) c on a.order_id = c.order_id 
and b.topping_id = c.excluded_toppings
left join
(Select Distinct customer_id,order_id, topping_id as Extra_toppings FROM customer_orders
Right Join
pizza_toppings ON FIND_IN_SET(topping_id, REPLACE(extras,' ', '')) > 0
where customer_id is not null) d on a.order_id = d.order_id 
and b.topping_id = d.Extra_toppings)),
CTE2 As
(Select topping_id, count(topping_id) as Total_Count, count(excluded_toppings) As Exclusions , count(extra_toppings) As Extras From CTE
group by topping_id)
select Topping_id, Total_count-Exclusions+EXTRAS as Final_Total_Count from cte2
order by Final_Total_Count desc;

									-- D. Pricing and Ratings --
                                    
-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes 
	-- how much money has Pizza Runner made so far if there are no delivery fees?

with CTE as
(select pizza_id,count(pizza_id) As pizza_count from customer_orders
join runner_orders using (order_id)
where cancellation = ''
group by pizza_id)
select *, 
case when pizza_id = 1 then concat('$',pizza_count*12) else concat('$',pizza_count*10) end as Total_earnings
from CTE;

-- 2. What if there was an additional $1 charge for any pizza extras?
	-- Add cheese is $1 extra
With CTE as
(select order_id, pizza_id, extras,
case when pizza_id = 1 then 12
	  when pizza_id = 2 then 10
      else 0 end as Pizza_coast
from customer_orders)
select order_id, pizza_id, 
case 
when Extras like '%4%' then Pizza_coast+2 
when Extras != '' then Pizza_coast+1 else Pizza_coast
end as Extra_Coast from CTE;

-- 3. The Pizza Runner team now wants to add an additional ratings system that allows 
	-- customers to rate their runner, how would you design an additional table for this new dataset 
	-- generate a schema for this new table and insert your own data for ratings for each successful 
    -- customer order between 1 to 5.
    
DROP TABLE IF EXISTS runners_ratting;
CREATE TABLE runners_ratting (
  runner_id INTEGER,
  Rating float
);
INSERT INTO runners_ratting
  (runner_id, Rating)
VALUES
  (1, 5),
  (2, 4.5),
  (3, 3.5),
  (4, 1);
SELECT * FROM runners_ratting;

















   
   
   
   
   
   
