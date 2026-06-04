-- =====================================================
-- LOGISTICS OPERATIONS ANALYSIS PROJECT
-- Database Setup & Data Loading
-- Author: Harshpreet Singh Kohli
-- =====================================================

CREATE DATABASE IF NOT EXISTS logistics_analytics;
USE logistics_analytics;

-- TABLE: TRIPS
CREATE TABLE trips (
    trip_id TEXT,
    load_id TEXT,
    driver_id TEXT,
    truck_id TEXT,
    trailer_id TEXT,
    dispatch_date DATETIME,
    actual_distance_miles DOUBLE,
    actual_duration_hours DOUBLE,
    fuel_gallons_used DOUBLE,
    average_mpg DOUBLE,
    idle_time_hours DOUBLE,
    trip_status TEXT
);

-- TABLE: LOADS
CREATE TABLE loads (
    load_id TEXT,
    customer_id TEXT,
    route_id TEXT,
    load_date DATETIME,
    load_type TEXT,
    weight_lbs DOUBLE,
    pieces INT,
    revenue DOUBLE,
    fuel_surcharge DOUBLE,
    accessorial_charges DOUBLE,
    load_status TEXT,
    booking_type TEXT
);

-- TABLE: DELIVERY EVENTS
CREATE TABLE delivery_events (
    event_id TEXT,
    load_id TEXT,
    trip_id TEXT,
    event_type TEXT,
    facility_id TEXT,
    scheduled_datetime DATETIME,
    actual_datetime DATETIME,
    detention_minutes DOUBLE,
    on_time_flag TEXT,
    location_city TEXT,
    location_state TEXT
);

-- TABLE: DRIVERS
CREATE TABLE drivers (
    driver_id TEXT,
    first_name TEXT,
    last_name TEXT,
    hire_date DATETIME,
    termination_date DATETIME,
    license_number TEXT,
    license_state TEXT,
    date_of_birth DATETIME,
    home_terminal TEXT,
    employment_status TEXT,
    cdl_class TEXT,
    years_experience DOUBLE
);

-- TABLE: TRUCKS
CREATE TABLE trucks (
    truck_id TEXT,
    unit_number INT,
    make TEXT,
    model_year INT,
    vin TEXT,
    acquisition_date DATETIME,
    acquisition_mileage DOUBLE,
    fuel_type TEXT,
    tank_capacity_gallons INT,
    status TEXT,
    home_terminal TEXT
);

-- TABLE: ROUTES
CREATE TABLE routes (
    route_id TEXT,
    origin_city TEXT,
    origin_state TEXT,
    destination_city TEXT,
    destination_state TEXT,
    typical_distance_miles DOUBLE,
    base_rate_per_mile DOUBLE,
    fuel_surcharge_rate DOUBLE,
    typical_transit_days DOUBLE
);

SET GLOBAL local_infile = 1;

-- DATA CLEANING
ALTER TABLE drivers
MODIFY termination_date DATETIME NULL;

UPDATE drivers
SET termination_date = NULL
WHERE DATE_FORMAT(termination_date, '%Y-%m-%d') = '0000-00-00';

-- DATA VALIDATION
SELECT COUNT(*) AS trips_count FROM trips;
SELECT COUNT(*) AS loads_count FROM loads;
SELECT COUNT(*) AS delivery_events_count FROM delivery_events;
SELECT COUNT(*) AS drivers_count FROM drivers;
SELECT COUNT(*) AS trucks_count FROM trucks;
SELECT COUNT(*) AS routes_count FROM routes;
