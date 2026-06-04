USE logistics_analytics;

-- =====================================================
-- LOGISTICS OPERATIONS & DELIVERY PERFORMANCE ANALYSIS
-- Author: Harshpreet Singh Kohli
-- Tools: MySQL, DBeaver, Power BI
--
-- Project Objective:
-- Analyze logistics operations data to identify delivery performance issues,
-- route deviations, driver attrition patterns, detention impact, and pickup-to-delivery
-- process flow bottlenecks.
-- =====================================================


-- =====================================================
-- STEP 1: DATA EXPLORATION
-- =====================================================

-- Business Question:
-- What tables, fields, and basic operational patterns are available for analysis?

-- Preview key tables
SELECT * FROM trips LIMIT 10;
SELECT * FROM loads LIMIT 10;
SELECT * FROM delivery_events LIMIT 10;
SELECT * FROM drivers LIMIT 10;
SELECT * FROM trucks LIMIT 10;
SELECT * FROM routes LIMIT 10;

-- Check available trip status values
SELECT DISTINCT trip_status
FROM trips;

-- Check total drivers and terminated drivers
SELECT 
    COUNT(*) AS total_drivers,
    COUNT(CASE WHEN employment_status = 'Terminated' THEN 1 END) AS terminated_drivers
FROM drivers;

-- Check important trip identifiers
SELECT 
    trip_id,
    load_id,
    driver_id,
    truck_id
FROM trips
LIMIT 10;

-- Check analysis period based on trip dispatch dates
SELECT 
    MIN(dispatch_date) AS first_dispatch_date,
    MAX(dispatch_date) AS last_dispatch_date
FROM trips;

-- Check trip distance range
SELECT 
    MIN(actual_distance_miles) AS min_actual_distance_miles,
    MAX(actual_distance_miles) AS max_actual_distance_miles,
    AVG(actual_distance_miles) AS avg_actual_distance_miles
FROM trips;


-- =====================================================
-- STEP 2: DRIVER ATTRITION ANALYSIS
-- =====================================================

-- Business Question:
-- Is driver attrition a workforce risk, and when are terminated drivers leaving?

-- Calculate driver attrition rate
SELECT 
    COUNT(*) AS total_drivers,
    COUNT(CASE WHEN employment_status = 'Terminated' THEN 1 END) AS terminated_drivers,
    ROUND(
        (COUNT(CASE WHEN employment_status = 'Terminated' THEN 1 END) * 100.0) / COUNT(*),
        2
    ) AS terminated_percentage
FROM drivers;

-- Review terminated drivers by experience and employment dates
SELECT 
    driver_id,
    hire_date,
    termination_date,
    employment_status,
    years_experience
FROM drivers
WHERE employment_status = 'Terminated'
ORDER BY years_experience ASC;

-- Calculate tenure in years for terminated drivers
SELECT 
    driver_id,
    hire_date,
    termination_date,
    TIMESTAMPDIFF(YEAR, hire_date, termination_date) AS tenure_years
FROM drivers
WHERE employment_status = 'Terminated';

-- Calculate tenure in months for more accurate attrition analysis
SELECT 
    driver_id,
    hire_date,
    termination_date,
    TIMESTAMPDIFF(MONTH, hire_date, termination_date) AS tenure_months
FROM drivers
WHERE employment_status = 'Terminated';

-- Analyze driver attrition by tenure bucket
SELECT 
    CASE 
        WHEN TIMESTAMPDIFF(MONTH, hire_date, termination_date) <= 12 THEN '0-12 Months'
        WHEN TIMESTAMPDIFF(MONTH, hire_date, termination_date) <= 24 THEN '12-24 Months'
        ELSE '24-36 Months'
    END AS tenure_bucket,
    COUNT(*) AS terminated_driver_count
FROM drivers
WHERE employment_status = 'Terminated'
GROUP BY 
    CASE 
        WHEN TIMESTAMPDIFF(MONTH, hire_date, termination_date) <= 12 THEN '0-12 Months'
        WHEN TIMESTAMPDIFF(MONTH, hire_date, termination_date) <= 24 THEN '12-24 Months'
        ELSE '24-36 Months'
    END
ORDER BY terminated_driver_count DESC;


-- =====================================================
-- STEP 3: ROUTE & TRANSIT PERFORMANCE ANALYSIS
-- =====================================================

-- Business Question:
-- Are actual trip outcomes aligned with planned route and transit assumptions?

-- Validate that trips successfully map to loads and revenue information
SELECT 
    t.trip_id,
    t.load_id,
    t.driver_id,
    l.route_id,
    l.revenue
FROM trips t
LEFT JOIN loads l
    ON t.load_id = l.load_id
LIMIT 20;

-- Validate that trips successfully map to planned route information
SELECT 
    t.trip_id,
    t.load_id,
    t.driver_id,
    l.route_id,
    l.revenue,
    r.typical_distance_miles,
    r.typical_transit_days
FROM trips t
LEFT JOIN loads l
    ON t.load_id = l.load_id
LEFT JOIN routes r
    ON l.route_id = r.route_id
LIMIT 20;

-- Identify trips with missing route information after join
SELECT 
    t.trip_id,
    t.load_id,
    t.driver_id,
    l.route_id,
    l.revenue,
    r.typical_distance_miles,
    r.typical_transit_days
FROM trips t
LEFT JOIN loads l
    ON t.load_id = l.load_id
LEFT JOIN routes r
    ON l.route_id = r.route_id
WHERE r.typical_distance_miles IS NULL;

-- Compare actual trip distance against planned route distance
SELECT 
    t.trip_id,
    t.load_id,
    t.driver_id,
    l.route_id,
    l.revenue,
    t.actual_distance_miles,
    r.typical_distance_miles,
    (t.actual_distance_miles - r.typical_distance_miles) AS distance_diff,
    ROUND(
        ((t.actual_distance_miles - r.typical_distance_miles) * 100.0) / r.typical_distance_miles,
        2
    ) AS distance_diff_pct,
    CASE 
        WHEN (t.actual_distance_miles - r.typical_distance_miles) = 0 THEN 'Accurate Route'
        WHEN (t.actual_distance_miles - r.typical_distance_miles) > 0 THEN 'Longer Than Expected'
        ELSE 'Shorter Than Expected'
    END AS route_accuracy
FROM trips t
LEFT JOIN loads l
    ON t.load_id = l.load_id
LEFT JOIN routes r
    ON l.route_id = r.route_id;

-- Summarize trips by route distance deviation category
SELECT
    CASE
        WHEN (t.actual_distance_miles - r.typical_distance_miles) = 0 THEN 'Accurate Route'
        WHEN (t.actual_distance_miles - r.typical_distance_miles) > 0 THEN 'Longer Than Expected'
        ELSE 'Shorter Than Expected'
    END AS route_accuracy,
    COUNT(*) AS trip_count,
    ROUND(AVG(t.actual_distance_miles - r.typical_distance_miles), 2) AS avg_distance_diff_miles
FROM trips t
LEFT JOIN loads l
    ON t.load_id = l.load_id
LEFT JOIN routes r
    ON l.route_id = r.route_id
GROUP BY
    CASE
        WHEN (t.actual_distance_miles - r.typical_distance_miles) = 0 THEN 'Accurate Route'
        WHEN (t.actual_distance_miles - r.typical_distance_miles) > 0 THEN 'Longer Than Expected'
        ELSE 'Shorter Than Expected'
    END
ORDER BY trip_count DESC;

-- Compare actual trip duration against planned transit time.
-- Note: typical_transit_days is stored as whole days, while actual_duration_hours is precise.
-- A ±12 hour tolerance is used to avoid overstating small differences.
SELECT
    CASE
        WHEN (t.actual_duration_hours - (r.typical_transit_days * 24)) BETWEEN -12 AND 12 THEN 'On Time'
        WHEN (t.actual_duration_hours - (r.typical_transit_days * 24)) > 12 THEN 'Longer Than Expected'
        ELSE 'Shorter Than Expected'
    END AS transit_diff_category,
    COUNT(*) AS trip_count,
    ROUND(AVG(t.actual_duration_hours - (r.typical_transit_days * 24)), 2) AS avg_duration_diff_hours
FROM trips t
LEFT JOIN loads l
    ON t.load_id = l.load_id
LEFT JOIN routes r
    ON l.route_id = r.route_id
GROUP BY 
    CASE
        WHEN (t.actual_duration_hours - (r.typical_transit_days * 24)) BETWEEN -12 AND 12 THEN 'On Time'
        WHEN (t.actual_duration_hours - (r.typical_transit_days * 24)) > 12 THEN 'Longer Than Expected'
        ELSE 'Shorter Than Expected'
    END
ORDER BY trip_count DESC;


-- =====================================================
-- STEP 4: DELIVERY PERFORMANCE ANALYSIS
-- =====================================================

-- Business Question:
-- How reliable is final delivery performance, and how large are delivery delays?

-- Calculate on-time delivery rate using delivery events only
SELECT 
    COUNT(*) AS total_deliveries,
    COUNT(CASE WHEN on_time_flag = 'True' THEN 1 END) AS on_time_deliveries,
    ROUND(
        (COUNT(CASE WHEN on_time_flag = 'True' THEN 1 END) * 100.0) / COUNT(*),
        2
    ) AS on_time_delivery_pct
FROM delivery_events
WHERE event_type = 'Delivery';

-- Calculate average delivery delay in minutes
SELECT 
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, scheduled_datetime, actual_datetime)), 2) AS avg_delay_minutes
FROM delivery_events
WHERE event_type = 'Delivery';

-- Classify delivery timing using exact scheduled vs actual timestamp comparison
SELECT 
    CASE 
        WHEN TIMESTAMPDIFF(MINUTE, scheduled_datetime, actual_datetime) = 0 THEN 'On Time'
        WHEN TIMESTAMPDIFF(MINUTE, scheduled_datetime, actual_datetime) > 0 THEN 'Late'
        ELSE 'Early'
    END AS delivery_timing_status,
    COUNT(*) AS delivery_count
FROM delivery_events
WHERE event_type = 'Delivery'
GROUP BY 
    CASE 
        WHEN TIMESTAMPDIFF(MINUTE, scheduled_datetime, actual_datetime) = 0 THEN 'On Time'
        WHEN TIMESTAMPDIFF(MINUTE, scheduled_datetime, actual_datetime) > 0 THEN 'Late'
        ELSE 'Early'
    END
ORDER BY delivery_count DESC;

-- Validate likely on-time logic using a ±120 minute tolerance window
SELECT 
    CASE 
        WHEN TIMESTAMPDIFF(MINUTE, scheduled_datetime, actual_datetime) BETWEEN -120 AND 120 THEN 'On Time'
        WHEN TIMESTAMPDIFF(MINUTE, scheduled_datetime, actual_datetime) > 120 THEN 'Late'
        ELSE 'Early'
    END AS delivery_status,
    COUNT(*) AS delivery_count
FROM delivery_events
WHERE event_type = 'Delivery'
GROUP BY 
    CASE 
        WHEN TIMESTAMPDIFF(MINUTE, scheduled_datetime, actual_datetime) BETWEEN -120 AND 120 THEN 'On Time'
        WHEN TIMESTAMPDIFF(MINUTE, scheduled_datetime, actual_datetime) > 120 THEN 'Late'
        ELSE 'Early'
    END
ORDER BY delivery_count DESC;


-- =====================================================
-- STEP 5: DETENTION ANALYSIS
-- =====================================================

-- Business Question:
-- Does detention time explain delivery delays, or is it a broader operational issue?

-- Calculate average detention time for delivery events
SELECT 
    ROUND(AVG(detention_minutes), 2) AS avg_detention_minutes
FROM delivery_events
WHERE event_type = 'Delivery';

-- Compare average detention time using dataset on-time flag
SELECT
    on_time_flag,
    COUNT(*) AS total_deliveries,
    ROUND(AVG(detention_minutes), 2) AS avg_detention_minutes
FROM delivery_events
WHERE event_type = 'Delivery'
GROUP BY on_time_flag
ORDER BY total_deliveries DESC;

-- Compare average detention time by delivery performance category
SELECT
    CASE 
        WHEN TIMESTAMPDIFF(MINUTE, scheduled_datetime, actual_datetime) BETWEEN -120 AND 120 THEN 'On Time'
        WHEN TIMESTAMPDIFF(MINUTE, scheduled_datetime, actual_datetime) > 120 THEN 'Late'
        ELSE 'Early'
    END AS delivery_status,
    COUNT(*) AS total_deliveries,
    ROUND(AVG(detention_minutes), 2) AS avg_detention_minutes
FROM delivery_events
WHERE event_type = 'Delivery'
GROUP BY
    CASE 
        WHEN TIMESTAMPDIFF(MINUTE, scheduled_datetime, actual_datetime) BETWEEN -120 AND 120 THEN 'On Time'
        WHEN TIMESTAMPDIFF(MINUTE, scheduled_datetime, actual_datetime) > 120 THEN 'Late'
        ELSE 'Early'
    END
ORDER BY total_deliveries DESC;


-- =====================================================
-- STEP 6: LOCATION-BASED DELIVERY PERFORMANCE
-- =====================================================

-- Business Question:
-- Which cities show the highest delivery delay risk?

SELECT
    location_city,
    COUNT(*) AS total_deliveries,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, scheduled_datetime, actual_datetime)), 2) AS avg_delay_minutes
FROM delivery_events
WHERE event_type = 'Delivery'
GROUP BY location_city
ORDER BY avg_delay_minutes DESC;


-- =====================================================
-- STEP 7: PICKUP VS DELIVERY FLOW ANALYSIS
-- =====================================================

-- Business Question:
-- How do pickup and delivery events connect within each trip lifecycle?

-- Create one row per trip by joining pickup and delivery events
SELECT
    p.trip_id,
    p.load_id,

    -- Pickup details
    p.location_city AS pickup_city,
    p.scheduled_datetime AS pickup_scheduled_time,
    p.actual_datetime AS pickup_actual_time,
    TIMESTAMPDIFF(MINUTE, p.scheduled_datetime, p.actual_datetime) AS pickup_delay_minutes,
    p.detention_minutes AS pickup_detention_minutes,

    -- Delivery details
    d.location_city AS delivery_city,
    d.scheduled_datetime AS delivery_scheduled_time,
    d.actual_datetime AS delivery_actual_time,
    TIMESTAMPDIFF(MINUTE, d.scheduled_datetime, d.actual_datetime) AS delivery_delay_minutes,
    d.detention_minutes AS delivery_detention_minutes
FROM delivery_events p
JOIN delivery_events d
    ON p.trip_id = d.trip_id
WHERE p.event_type = 'Pickup'
  AND d.event_type = 'Delivery';


-- =====================================================
-- STEP 8: DELAY PROPAGATION ANALYSIS
-- =====================================================

-- Business Question:
-- Do pickup delays propagate into final delivery outcomes?

-- Analyze delivery outcomes by pickup status
SELECT
    CASE
        WHEN TIMESTAMPDIFF(MINUTE, p.scheduled_datetime, p.actual_datetime) BETWEEN -120 AND 120 THEN 'On Time'
        WHEN TIMESTAMPDIFF(MINUTE, p.scheduled_datetime, p.actual_datetime) > 120 THEN 'Late'
        ELSE 'Early'
    END AS pickup_status,

    CASE 
        WHEN TIMESTAMPDIFF(MINUTE, d.scheduled_datetime, d.actual_datetime) BETWEEN -120 AND 120 THEN 'On Time'
        WHEN TIMESTAMPDIFF(MINUTE, d.scheduled_datetime, d.actual_datetime) > 120 THEN 'Late'
        ELSE 'Early'
    END AS delivery_status,

    COUNT(*) AS total_trips,
    ROUND(AVG(p.detention_minutes), 2) AS avg_pickup_detention_minutes,
    ROUND(AVG(d.detention_minutes), 2) AS avg_delivery_detention_minutes
FROM delivery_events p
JOIN delivery_events d
    ON p.trip_id = d.trip_id
WHERE p.event_type = 'Pickup'
  AND d.event_type = 'Delivery'
GROUP BY pickup_status, delivery_status
ORDER BY total_trips DESC;

-- Calculate delivery outcome percentage within each pickup status
WITH pickup_delivery_status AS (
    SELECT
        CASE
            WHEN TIMESTAMPDIFF(MINUTE, p.scheduled_datetime, p.actual_datetime) BETWEEN -120 AND 120 THEN 'On Time'
            WHEN TIMESTAMPDIFF(MINUTE, p.scheduled_datetime, p.actual_datetime) > 120 THEN 'Late'
            ELSE 'Early'
        END AS pickup_status,

        CASE 
            WHEN TIMESTAMPDIFF(MINUTE, d.scheduled_datetime, d.actual_datetime) BETWEEN -120 AND 120 THEN 'On Time'
            WHEN TIMESTAMPDIFF(MINUTE, d.scheduled_datetime, d.actual_datetime) > 120 THEN 'Late'
            ELSE 'Early'
        END AS delivery_status
    FROM delivery_events p
    JOIN delivery_events d
        ON p.trip_id = d.trip_id
    WHERE p.event_type = 'Pickup'
      AND d.event_type = 'Delivery'
)
SELECT
    pickup_status,
    delivery_status,
    COUNT(*) AS total_trips,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY pickup_status),
        2
    ) AS percentage_within_pickup_status
FROM pickup_delivery_status
GROUP BY pickup_status, delivery_status
ORDER BY pickup_status, total_trips DESC;


-- =====================================================
-- FINAL DASHBOARD DATASETS
-- =====================================================

-- These queries generate clean analysis-ready datasets for Power BI.
-- Export each result as a CSV from DBeaver.

-- -----------------------------------------------------
-- DASHBOARD DATASET 1: DELIVERY PERFORMANCE
-- -----------------------------------------------------
SELECT
    trip_id,
    location_city,
    TIMESTAMPDIFF(MINUTE, scheduled_datetime, actual_datetime) AS delay_minutes,
    CASE 
        WHEN TIMESTAMPDIFF(MINUTE, scheduled_datetime, actual_datetime) BETWEEN -120 AND 120 THEN 'On Time'
        WHEN TIMESTAMPDIFF(MINUTE, scheduled_datetime, actual_datetime) > 120 THEN 'Late'
        ELSE 'Early'
    END AS delivery_status,
    detention_minutes,
    on_time_flag
FROM delivery_events
WHERE event_type = 'Delivery';


-- -----------------------------------------------------
-- DASHBOARD DATASET 2: ROUTE ANALYSIS
-- -----------------------------------------------------
SELECT
    t.trip_id,
    l.route_id,
    t.actual_distance_miles,
    r.typical_distance_miles,
    (t.actual_distance_miles - r.typical_distance_miles) AS distance_diff,
    CASE
        WHEN (t.actual_distance_miles - r.typical_distance_miles) = 0 THEN 'Accurate Route'
        WHEN (t.actual_distance_miles - r.typical_distance_miles) > 0 THEN 'Longer Than Expected'
        ELSE 'Shorter Than Expected'
    END AS route_accuracy
FROM trips t
LEFT JOIN loads l
    ON t.load_id = l.load_id
LEFT JOIN routes r
    ON l.route_id = r.route_id;


-- -----------------------------------------------------
-- DASHBOARD DATASET 3: DRIVER ATTRITION
-- -----------------------------------------------------
SELECT
    driver_id,
    employment_status,
    years_experience,
    TIMESTAMPDIFF(MONTH, hire_date, termination_date) AS tenure_months,
    CASE 
        WHEN TIMESTAMPDIFF(MONTH, hire_date, termination_date) <= 12 THEN '0-12 Months'
        WHEN TIMESTAMPDIFF(MONTH, hire_date, termination_date) <= 24 THEN '12-24 Months'
        ELSE '24-36 Months'
    END AS tenure_bucket
FROM drivers
WHERE employment_status = 'Terminated';


-- -----------------------------------------------------
-- DASHBOARD DATASET 4: PICKUP VS DELIVERY FLOW
-- -----------------------------------------------------
SELECT
    p.trip_id,
    CASE
        WHEN TIMESTAMPDIFF(MINUTE, p.scheduled_datetime, p.actual_datetime) BETWEEN -120 AND 120 THEN 'On Time'
        WHEN TIMESTAMPDIFF(MINUTE, p.scheduled_datetime, p.actual_datetime) > 120 THEN 'Late'
        ELSE 'Early'
    END AS pickup_status,

    CASE
        WHEN TIMESTAMPDIFF(MINUTE, d.scheduled_datetime, d.actual_datetime) BETWEEN -120 AND 120 THEN 'On Time'
        WHEN TIMESTAMPDIFF(MINUTE, d.scheduled_datetime, d.actual_datetime) > 120 THEN 'Late'
        ELSE 'Early'
    END AS delivery_status,

    TIMESTAMPDIFF(MINUTE, p.scheduled_datetime, p.actual_datetime) AS pickup_delay_minutes,
    TIMESTAMPDIFF(MINUTE, d.scheduled_datetime, d.actual_datetime) AS delivery_delay_minutes,
    p.detention_minutes AS pickup_detention_minutes,
    d.detention_minutes AS delivery_detention_minutes
FROM delivery_events p
JOIN delivery_events d
    ON p.trip_id = d.trip_id
WHERE p.event_type = 'Pickup'
  AND d.event_type = 'Delivery';


-- =====================================================
-- KEY FINDINGS SUMMARY
-- =====================================================

-- 1. Driver attrition is 17.33%, with the highest attrition in the 12-24 month tenure range.
-- 2. Most trips exceed planned route distances, indicating recurring deviation from route assumptions.
-- 3. Despite longer actual distances, many trips are still completed within or below expected transit windows.
-- 4. On-time delivery performance remains below operational expectations.
-- 5. Average detention time remains high across delivery categories, suggesting a systemic facility-level issue.
-- 6. Pickup delays show limited downstream impact on final delivery outcomes.
