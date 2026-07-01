-- ============================================================
-- streamlit_project Database — Full Setup Script
-- Based on: dvd_fix / dvdrental (Sakila) schema
--
-- Run this in PostgreSQL to create a fresh copy:
--   createdb streamlit_project
--   psql -U postgres -d streamlit_project -f sql/02_create_streamlit_project.sql
--
-- Or to run on existing data in dvd_fix:
--   psql -U postgres -d dvd_fix -f sql/02_create_streamlit_project.sql
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- STEP 0 · Extensions
-- ─────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─────────────────────────────────────────────────────────────
-- STEP 1 · DIMENSION TABLES
-- ─────────────────────────────────────────────────────────────

-- dim_film
CREATE TABLE IF NOT EXISTS dim_film (
    sk_film          INTEGER PRIMARY KEY,
    film_id          INTEGER,
    title            VARCHAR(255),
    rating           VARCHAR(10),
    rental_rate      DECIMAL(4,2),
    rental_duration  INTEGER,
    replacement_cost DECIMAL(5,2),
    length           INTEGER,
    special_features TEXT
);
TRUNCATE TABLE dim_film;
INSERT INTO dim_film
SELECT film_id, film_id, title, rating, rental_rate,
       rental_duration, replacement_cost, length,
       COALESCE(special_features::TEXT, '')
FROM film;

-- dim_genre
CREATE TABLE IF NOT EXISTS dim_genre (
    sk_genre   INTEGER PRIMARY KEY,
    genre_id   INTEGER,
    genre_name VARCHAR(25)
);
TRUNCATE TABLE dim_genre;
INSERT INTO dim_genre SELECT category_id, category_id, name FROM category;

-- dim_date
CREATE TABLE IF NOT EXISTS dim_date (
    sk_date         SERIAL PRIMARY KEY,
    full_date       DATE NOT NULL,
    year            INTEGER,
    month           INTEGER,
    week_number     INTEGER,
    week_start_date DATE,
    week_end_date   DATE
);
TRUNCATE TABLE dim_date;
INSERT INTO dim_date (full_date, year, month, week_number, week_start_date, week_end_date)
SELECT DISTINCT
    d::DATE,
    EXTRACT(YEAR  FROM d)::INTEGER,
    EXTRACT(MONTH FROM d)::INTEGER,
    EXTRACT(WEEK  FROM d)::INTEGER,
    DATE_TRUNC('week', d)::DATE,
    (DATE_TRUNC('week', d) + INTERVAL '6 days')::DATE
FROM generate_series(
    (SELECT MIN(rental_date) FROM rental),
    (SELECT MAX(rental_date) FROM rental),
    INTERVAL '1 day'
) AS d;


-- ─────────────────────────────────────────────────────────────
-- STEP 2 · FACT TABLES
-- ─────────────────────────────────────────────────────────────

-- fact_rental
CREATE TABLE IF NOT EXISTS fact_rental (
    sk_rental   SERIAL PRIMARY KEY,
    rental_id   INTEGER,
    sk_film     INTEGER,
    sk_genre    INTEGER,
    sk_date     INTEGER,
    rental_date TIMESTAMP,
    return_date TIMESTAMP,
    amount      DECIMAL(5,2),
    customer_id INTEGER,
    staff_id    INTEGER
);
TRUNCATE TABLE fact_rental;
INSERT INTO fact_rental
    (rental_id, sk_film, sk_genre, sk_date, rental_date, return_date, amount, customer_id, staff_id)
SELECT
    r.rental_id, f.film_id, fc.category_id, dd.sk_date,
    r.rental_date, r.return_date, COALESCE(p.amount, 0),
    r.customer_id, r.staff_id
FROM rental r
JOIN inventory     i  ON r.inventory_id  = i.inventory_id
JOIN film          f  ON i.film_id        = f.film_id
JOIN film_category fc ON f.film_id        = fc.film_id
JOIN payment       p  ON r.rental_id      = p.rental_id
JOIN dim_date     dd  ON dd.full_date     = r.rental_date::DATE;

-- fact_inventory
CREATE TABLE IF NOT EXISTS fact_inventory (
    sk_inventory SERIAL PRIMARY KEY,
    sk_film      INTEGER,
    store_id     INTEGER,
    total_copies INTEGER
);
TRUNCATE TABLE fact_inventory;
INSERT INTO fact_inventory (sk_film, store_id, total_copies)
SELECT film_id, store_id, COUNT(*) FROM inventory GROUP BY film_id, store_id;


-- ─────────────────────────────────────────────────────────────
-- STEP 3 · SUMMARY / OLAP TABLES
-- ─────────────────────────────────────────────────────────────

-- summary_genre
CREATE TABLE IF NOT EXISTS summary_genre (
    genre_name    VARCHAR(25) PRIMARY KEY,
    total_rental  INTEGER,
    total_revenue DECIMAL(10,2),
    best_film     VARCHAR(255),
    revenue_pct   DECIMAL(5,2)
);
TRUNCATE TABLE summary_genre;
INSERT INTO summary_genre
WITH base AS (
    SELECT dg.genre_name,
           COUNT(fr.sk_rental)  AS total_rental,
           SUM(fr.amount)       AS total_revenue
    FROM fact_rental fr
    JOIN dim_genre   dg ON fr.sk_genre = dg.sk_genre
    GROUP BY dg.genre_name
),
best AS (
    SELECT DISTINCT ON (dg.genre_name)
           dg.genre_name,
           df.title AS best_film
    FROM fact_rental fr
    JOIN dim_genre dg ON fr.sk_genre = dg.sk_genre
    JOIN dim_film  df ON fr.sk_film  = df.sk_film
    GROUP BY dg.genre_name, df.title
    ORDER BY dg.genre_name, COUNT(*) DESC
)
SELECT base.genre_name, base.total_rental, base.total_revenue, best.best_film,
       ROUND(base.total_revenue / SUM(base.total_revenue) OVER () * 100, 2)
FROM base
JOIN best ON base.genre_name = best.genre_name;

-- summary_rating
CREATE TABLE IF NOT EXISTS summary_rating (
    rating              VARCHAR(10) PRIMARY KEY,
    total_rental        INTEGER,
    total_revenue       DECIMAL(10,2),
    num_films           INTEGER,
    avg_rental_per_film DECIMAL(8,2),
    rental_pct          DECIMAL(5,2)
);
TRUNCATE TABLE summary_rating;
INSERT INTO summary_rating
SELECT
    df.rating,
    COUNT(fr.sk_rental)::INTEGER,
    COALESCE(SUM(fr.amount), 0),
    COUNT(DISTINCT fr.sk_film),
    ROUND(COUNT(fr.sk_rental)::DECIMAL / NULLIF(COUNT(DISTINCT fr.sk_film), 0), 2),
    ROUND(COUNT(fr.sk_rental)::DECIMAL / NULLIF(SUM(COUNT(fr.sk_rental)) OVER (), 0) * 100, 2)
FROM fact_rental fr
JOIN dim_film df ON fr.sk_film = df.sk_film
GROUP BY df.rating;

-- summary_weekly_genre
CREATE TABLE IF NOT EXISTS summary_weekly_genre (
    genre_name      VARCHAR(25),
    week_start_date DATE,
    week_number     INTEGER,
    year            INTEGER,
    weekly_rental   INTEGER,
    PRIMARY KEY (genre_name, week_start_date)
);
TRUNCATE TABLE summary_weekly_genre;
INSERT INTO summary_weekly_genre
SELECT dg.genre_name, dd.week_start_date, dd.week_number, dd.year,
       COUNT(fr.sk_rental)::INTEGER
FROM fact_rental fr
JOIN dim_genre dg ON fr.sk_genre = dg.sk_genre
JOIN dim_date  dd ON fr.sk_date  = dd.sk_date
GROUP BY dg.genre_name, dd.week_start_date, dd.week_number, dd.year;

-- summary_inventory
CREATE TABLE IF NOT EXISTS summary_inventory (
    sk_film        INTEGER PRIMARY KEY,
    title          VARCHAR(255),
    current_stock  INTEGER,
    rental_per_day DECIMAL(8,4),
    days_to_empty  INTEGER,
    stock_status   VARCHAR(10)
);
TRUNCATE TABLE summary_inventory;
WITH rental_velocity AS (
    SELECT
        i.film_id,
        COUNT(r.rental_id)::DECIMAL /
        GREATEST(EXTRACT(DAY FROM
            (COALESCE(MAX(r.rental_date), NOW()) - COALESCE(MIN(r.rental_date), NOW()))
        ), 1) AS rental_per_day
    FROM inventory i
    LEFT JOIN rental r ON i.inventory_id = r.inventory_id
    GROUP BY i.film_id
),
stock_count AS (
    SELECT film_id, COUNT(*) AS total_copies FROM inventory GROUP BY film_id
),
rented_out AS (
    SELECT i.film_id, COUNT(*) AS rented_count
    FROM rental r
    JOIN inventory i ON r.inventory_id = i.inventory_id
    WHERE r.return_date IS NULL
    GROUP BY i.film_id
)
INSERT INTO summary_inventory
SELECT
    f.film_id,
    f.title,
    GREATEST(COALESCE(sc.total_copies,0) - COALESCE(ro.rented_count,0), 0) AS current_stock,
    COALESCE(rv.rental_per_day, 0),
    CASE
        WHEN COALESCE(rv.rental_per_day, 0) = 0 THEN 9999
        WHEN GREATEST(COALESCE(sc.total_copies,0) - COALESCE(ro.rented_count,0), 0) = 0 THEN 9999
        ELSE (GREATEST(COALESCE(sc.total_copies,0) - COALESCE(ro.rented_count,0), 0)
              / rv.rental_per_day)::INTEGER
    END AS days_to_empty,
    CASE
        WHEN GREATEST(COALESCE(sc.total_copies,0) - COALESCE(ro.rented_count,0), 0) = 0  THEN 'OUT OF STOCK'
        WHEN GREATEST(COALESCE(sc.total_copies,0) - COALESCE(ro.rented_count,0), 0) <= 1 THEN 'CRITICAL'
        WHEN GREATEST(COALESCE(sc.total_copies,0) - COALESCE(ro.rented_count,0), 0) <= 3 THEN 'WARNING'
        ELSE 'OK'
    END AS stock_status
FROM film f
INNER JOIN stock_count  sc ON f.film_id = sc.film_id
LEFT  JOIN rented_out   ro ON f.film_id = ro.film_id
LEFT  JOIN rental_velocity rv ON f.film_id = rv.film_id
WHERE sc.total_copies > 0;

-- summary_film_features  (ML input table)
CREATE TABLE IF NOT EXISTS summary_film_features (
    film_id          INTEGER PRIMARY KEY,
    title            TEXT,
    genre_name       TEXT,
    rating           TEXT,
    length           INTEGER,
    rental_rate      DECIMAL(4,2),
    replacement_cost DECIMAL(5,2),
    rental_duration  INTEGER,
    num_actors       INTEGER,
    special_features TEXT,
    total_rental     INTEGER,
    total_revenue    DECIMAL(10,2),
    is_popular       BOOLEAN
);
TRUNCATE TABLE summary_film_features;
INSERT INTO summary_film_features
SELECT
    f.film_id,
    f.title,
    c.name AS genre_name,
    f.rating,
    f.length,
    f.rental_rate,
    f.replacement_cost,
    f.rental_duration,
    COALESCE(actor_count.num_actors, 0)        AS num_actors,
    f.special_features,
    COALESCE(rental_stats.total_rental, 0)     AS total_rental,
    COALESCE(rental_stats.total_revenue, 0)    AS total_revenue,
    CASE
        WHEN COALESCE(rental_stats.total_rental, 0) >= (
            SELECT PERCENTILE_CONT(0.6) WITHIN GROUP (ORDER BY rental_count)
            FROM (
                SELECT COUNT(r.rental_id) AS rental_count
                FROM rental r
                JOIN inventory i ON r.inventory_id = i.inventory_id
                GROUP BY i.film_id
            ) sub
        ) THEN TRUE
        ELSE FALSE
    END AS is_popular
FROM film f
LEFT JOIN film_category fc ON f.film_id = fc.film_id
LEFT JOIN category       c ON fc.category_id = c.category_id
LEFT JOIN (
    SELECT film_id, COUNT(actor_id) AS num_actors
    FROM film_actor GROUP BY film_id
) actor_count ON f.film_id = actor_count.film_id
LEFT JOIN (
    SELECT
        i.film_id,
        COUNT(r.rental_id)          AS total_rental,
        COALESCE(SUM(p.amount), 0)  AS total_revenue
    FROM inventory i
    LEFT JOIN rental  r ON i.inventory_id = r.inventory_id
    LEFT JOIN payment p ON r.rental_id    = p.rental_id
    GROUP BY i.film_id
) rental_stats ON f.film_id = rental_stats.film_id
WHERE EXISTS (SELECT 1 FROM inventory i WHERE i.film_id = f.film_id);


-- ─────────────────────────────────────────────────────────────
-- STEP 4 · KPI VIEW  (bonus — used optionally by dashboards)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW kpi_overview AS
SELECT
    (SELECT COUNT(*)              FROM film)                                 AS total_films,
    (SELECT COUNT(*)              FROM rental)                               AS total_rentals,
    (SELECT COALESCE(SUM(amount),0) FROM payment)                           AS total_revenue,
    (SELECT COUNT(DISTINCT customer_id) FROM rental)                        AS unique_customers,
    (SELECT genre_name FROM summary_genre ORDER BY total_revenue DESC LIMIT 1) AS top_genre_by_revenue,
    (SELECT rating     FROM summary_rating ORDER BY total_rental  DESC LIMIT 1) AS top_rating_by_rentals,
    (SELECT COUNT(*)   FROM summary_inventory WHERE stock_status = 'CRITICAL') AS critical_stock_count,
    (SELECT COUNT(*)   FROM summary_inventory WHERE stock_status = 'OUT OF STOCK') AS out_of_stock_count,
    (SELECT COUNT(*)   FROM summary_film_features WHERE is_popular = TRUE)  AS popular_films_count,
    NOW() AS refreshed_at;

-- ─────────────────────────────────────────────────────────────
-- STEP 5 · EDA / Quick-check queries (run manually as needed)
-- ─────────────────────────────────────────────────────────────

-- EDA 1: Genre distribution of films
-- SELECT genre_name, COUNT(*) AS film_count,
--        ROUND(AVG(f.length)) AS avg_length,
--        ROUND(AVG(f.rental_rate::NUMERIC),2) AS avg_rate
-- FROM summary_film_features sff
-- JOIN film f ON sff.film_id = f.film_id
-- GROUP BY genre_name ORDER BY film_count DESC;

-- EDA 2: Popularity rate per genre
-- SELECT genre_name,
--        COUNT(*) AS total,
--        SUM(CASE WHEN is_popular THEN 1 ELSE 0 END) AS popular_count,
--        ROUND(100.0 * SUM(CASE WHEN is_popular THEN 1 ELSE 0 END) / COUNT(*), 1) AS popularity_pct
-- FROM summary_film_features
-- GROUP BY genre_name ORDER BY popularity_pct DESC;

-- EDA 3: Rating × popularity cross-tab
-- SELECT rating,
--        SUM(CASE WHEN is_popular THEN 1 ELSE 0 END)::INTEGER AS popular,
--        SUM(CASE WHEN NOT is_popular THEN 1 ELSE 0 END)::INTEGER AS not_popular,
--        COUNT(*) AS total
-- FROM summary_film_features GROUP BY rating ORDER BY rating;

-- EDA 4: Revenue by rating
-- SELECT * FROM summary_rating ORDER BY total_revenue DESC;

-- EDA 5: KPI snapshot
-- SELECT * FROM kpi_overview;

COMMIT;
