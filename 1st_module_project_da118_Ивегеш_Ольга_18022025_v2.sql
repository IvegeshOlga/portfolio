/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Ольга Ивегеш, когорта 118
 * Дата: 18.02.2025
*/

-- Пример фильтрации данных от аномальных значений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT 
    CASE 
        WHEN city LIKE '%анкт-Петербург' 
        THEN 'Санкт-Петербург'
        ELSE 'ЛенОбл'
    END region,
    CASE 
        WHEN days_exposition>180 
        THEN 'Больше полугода'
        WHEN days_exposition>90 AND days_exposition<=180
        THEN 'Полгода'
        WHEN days_exposition>30 AND days_exposition<=90
        THEN 'Квартал'
        ELSE 'Месяц'
    END action,
    count(*),
    round(avg(last_price/total_area)::NUMERIC, 2) AS avg_cost_per_m,
    round(avg(total_area)::NUMERIC, 2) AS avg_total_area,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS median_floor
FROM real_estate.flats
LEFT JOIN real_estate.city c using(city_id)
LEFT JOIN real_estate.type t using(type_id)
LEFT JOIN real_estate.advertisement a using(id) 
WHERE id IN (SELECT * FROM filtered_id) AND "type" LIKE '%город' AND days_exposition IS NOT null
GROUP BY region, action;


-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
start_exposition AS(
    SELECT 
        count(id) AS count_start_on_month, 
        (EXTRACT(Month FROM first_day_exposition)) AS MONTH ,
        round(avg(last_price/total_area)::numeric,2) AS avg_cost_per_m_start,
        round(avg(total_area)::NUMERIC, 2) AS avg_total_area_start,
        rank() over(ORDER BY count(*) desc) AS start_rank
    FROM real_estate.advertisement a 
    JOIN  real_estate.flats using (id)
    JOIN real_estate.type as t using (type_id) 
    WHERE id IN (SELECT * FROM filtered_id) AND "type" LIKE '%город'
    GROUP BY month
),
finish_exposition AS(
    SELECT 
        count(id) AS count_finish_on_month, 
        (EXTRACT(Month FROM (first_day_exposition+days_exposition*INTERVAL'1 day' ))) AS MONTH,
        round(avg(last_price/total_area)::numeric,2) AS avg_cost_per_m_finish,
        round(avg(total_area)::NUMERIC, 2) AS avg_total_area_finish,
        rank() over(ORDER BY count(*) desc) AS finish_rank
    FROM real_estate.advertisement a 
    JOIN  real_estate.flats using (id)
    JOIN real_estate.type as t using (type_id) 
    WHERE id IN (SELECT * FROM filtered_id) AND "type" LIKE '%город' AND days_exposition IS NOT null
    GROUP BY month
)
-- Выведем объявления без выбросов:
SELECT 
    CASE 
        WHEN MONTH=1 THEN 'Январь'
        WHEN MONTH=2 THEN 'Февраль'
        WHEN MONTH=3 THEN 'Март'
        WHEN MONTH=4 THEN 'Апрель'
        WHEN MONTH=5 THEN 'Май'
        WHEN MONTH=6 THEN 'Июнь'
        WHEN MONTH=7 THEN 'Июль'
        WHEN MONTH=8 THEN 'Август'
        WHEN MONTH=9 THEN 'Сентябрь'
        WHEN MONTH=10 THEN 'Октябрь'
        WHEN MONTH=11 THEN 'Ноябрь'
        ELSE 'Декабрь'
    END AS month, *
    FROM start_exposition
JOIN finish_exposition using(month);

-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
rating AS (
    SELECT city,
        count(*) AS count_flats
    FROM real_estate.advertisement a
    JOIN real_estate.flats f USING (id)
    JOIN real_estate.city c using(city_id)
    WHERE id IN (SELECT * FROM filtered_id) AND city NOT LIKE '%анкт-Петербург'
    GROUP BY city
    ORDER BY count_flats DESC
LIMIT 15
)
-- Выведем объявления без выбросов:
SELECT 
    city, count(*) AS count_flats,
    Round(count(days_exposition)::numeric/Count(*),3) AS part,
    round(avg(last_price/total_area)::numeric,2) AS avg_cost_per_m,
    round(avg(total_area)::NUMERIC, 2) AS avg_total_area,
    round(avg(days_exposition)::NUMERIC, 0) AS avg_days_exposition
FROM real_estate.flats
LEFT JOIN real_estate.city c using(city_id)
LEFT JOIN real_estate.advertisement a using(id) 
WHERE id IN (SELECT * FROM filtered_id) AND city NOT LIKE '%анкт-Петербург' AND city IN (SELECT city FROM rating)
GROUP BY city
HAVING COUNT(*)>50
ORDER BY part DESC;