/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Ольга Ивегеш, когорта 118
 * Дата: 26.01.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков
-- 1.1. Доля платящих пользователей по всем данным:
-- title: Часть 1. Запрос 1.1
WITH payer_user AS (--платящие игроки
SELECT 
    id,
    count(payer) AS count_payer
FROM fantasy.users u 
WHERE payer=1
GROUP BY id), 
all_user AS ( -- все игроки
SELECT 
    id, 
    count(id) AS count_user
FROM fantasy.users u
GROUP BY id)
SELECT 
    SUM(count_user) AS count_user, --общее количество зарегистрированных игроков 
    SUM(count_payer) AS count_payer, -- количество платящих игроков
    ROUND(SUM(count_payer)/SUM(count_user)::numeric,4) AS part --доля платящих игроков
FROM all_user
LEFT JOIN payer_user using(id);

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- title: Часть 1. Запрос 1.2
WITH payer_user AS (--платящие игроки
SELECT 
    id, 
    race_id,
    count(payer) AS count_payer
FROM fantasy.users u 
WHERE payer=1
GROUP BY id, race_id), 
all_user AS ( -- все игроки
SELECT 
    id,
    race_id, 
    count(id) AS count_user
FROM fantasy.users u
GROUP BY id, race_id)
SELECT 
    race, --раса
    SUM(count_payer) AS count_payer, --количество платящих игроков
    SUM(count_user) AS count_user, --общее количество зарегистрированных игроков
    ROUND(SUM(count_payer)/SUM(count_user)::numeric,4) AS part -- доля платящих
FROM all_user
LEFT JOIN payer_user using(id, race_id) 
LEFT JOIN fantasy.race using(race_id) --присоединяем таблицу с названием расы
GROUP BY race
ORDER BY part desc;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- title: Часть 1. Запрос 2.1
SELECT 
    count(transaction_id) AS total_events, -- общее количество покупок
    sum(amount) AS total_amount, -- суммарная стоимость всех покупок
    min(amount) AS min_amount, -- минимальная стоимость покупки
    max(amount) AS max_amount, -- максимальная стоимость покупки
    round(avg(amount)::NUMERIC,2) AS avg_amount, -- среднее значение стоимости покупки
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median, -- медиана
    STDDEV(amount) AS stand_dev -- стандартное отклонение
FROM fantasy.events;
-- 2.2: Аномальные нулевые покупки:
-- title: Часть 1. Запрос 2.2
WITH zero AS (--нулевые транзакции
SELECT 
    transaction_id,
    count(*) AS count_zero
FROM fantasy.events e
WHERE amount=0
GROUP BY transaction_id), 
all_events AS (--все транзакции
SELECT 
    transaction_id,
    count(*) AS count_total
FROM fantasy.events e
GROUP BY transaction_id)
SELECT 
    SUM(count_total) AS count_total, --общее количество транзакций
    SUM(count_zero) AS count_zero, -- количество нулевых транзакций
    SUM(count_zero)/SUM(count_total) AS part --доля нулевых транзакций
FROM all_events
LEFT JOIN zero using(transaction_id);

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
-- title: Часть 1. Запрос 2.3
WITH user_payer AS
  (SELECT u.id,
          sum(e.amount) AS amount, 
          transaction_id,
          u.payer
   FROM fantasy.users u
   LEFT JOIN fantasy.events e USING(id)
   WHERE amount<>0  --убираем нулевые
   GROUP BY 
       u.id,
       transaction_id,
       u.payer
   )
SELECT CASE
        WHEN payer=1 THEN 'Платящие игроки'
        ELSE 'Неплатящие игроки'
    END AS player_group,-- категория
       COUNT(DISTINCT id),
       count(transaction_id)/COUNT(DISTINCT id) AS avg_events,
       Round((sum(amount)/COUNT(DISTINCT id))::numeric,2) AS avg_amount
FROM user_payer
GROUP BY player_group;

-- 2.4: Популярные эпические предметы:
-- title: Часть 1. Запрос 2.4
WITH all_transactions AS(--все транзакции, исключая нулевые
SELECT 
    id,
    item_code,
    count(transaction_id) AS count_total
FROM fantasy.events AS e
WHERE e.amount<>0
GROUP BY 
    transaction_id,
    id,
    item_code),
item_users AS ( --юзеры, которые покупали эпические предметы
SELECT 
    item_code,
    count(DISTINCT id) AS count_user
FROM fantasy.events
WHERE amount<>0
GROUP BY item_code
)
SELECT 
    game_items, --название эпического предмета 
    SUM(count_total) AS total_count, -- общее количество транзакций
--доля продаж каждого предмета
    SUM(count_total)/(SELECT count(*) FROM fantasy.events AS e WHERE e.amount IS NOT NULL AND e.amount<>0) AS part_transactions, 
--доля игроков, которые покупали хоть раз этот предмет
    count_user::real/(SELECT count(*) FROM fantasy.users) AS part_user
FROM all_transactions AS at
LEFT JOIN fantasy.items using(item_code)
LEFT JOIN item_users USING(item_code)
GROUP BY count_user, game_items
ORDER BY part_user DESC;

-- Часть 2. Решение ad hoc-задач
-- title: Часть 2. Задача 1
WITH from_events AS (
SELECT
    id,
    SUM(amount) AS amount_per_user, --общая сумма покупки юзера
    count(transaction_id) AS total_transaction, --количество транзакци  
    count(DISTINCT id) AS bayer_count --покупающие игроки
FROM fantasy.events
WHERE amount<>0
GROUP BY id), 
from_users AS ( 
SELECT 
    id,
    race_id,
    payer,
    count(*) AS payer_count --платящие/неплатящие игроки из всех игроков
FROM fantasy.users 
GROUP BY id, race_id, payer
ORDER BY race_id),
from_users_events AS (
SELECT 
    DISTINCT id,
    count(DISTINCT id) AS payer_bayer_count
FROM fantasy.events
JOIN fantasy.users using(id)
WHERE amount<>0 and payer=1
GROUP BY id
)
SELECT 
    race, --раса
    SUM(payer_count) AS total_count, --общее количество зарегистрированных игроков
    SUM(bayer_count) AS bayer_count, --количество покупающих игроков
    round((SUM(bayer_count)/SUM(payer_count))::numeric,2) AS part_bayer, --доля покупателей среди игроков
    round(((SUM(payer_count) FILTER (WHERE payer=1))/SUM(bayer_count))::numeric,2) AS part_bayer_payer, -- доля платящих среди покупающих
    round((SUM(payer_bayer_count)/SUM(bayer_count))::numeric,2) AS part_payer, 
    round((SUM(total_transaction)/SUM(bayer_count))::numeric,2) AS avg_transaction_per_user, --среднее количество покупок на одного игрока
    round((Sum(amount_per_user)/SUM(total_transaction))::numeric,2) AS avg_amount, --средняя стоимость одной покупки
    round((sum(amount_per_user)/SUM(bayer_count))::numeric,2) AS avg_amount2 --средняя суммарная стоимость
FROM from_users
LEFT JOIN from_events using(id)
LEFT JOIN from_users_events USING(id)
LEFT JOIN fantasy.race using(race_id) --присоединяем таблицу с названием расы
GROUP BY race;

-- Задача 2: Частота покупок
-- title: Часть 2. Задача 2
WITH total_transaction AS ( --Общее количество ненулевых транзакций, исключая неактивных пользователей (менее 25 покупок)
SELECT 
    id,
    count(total_transaction) AS count_total_transaction,
    ntile(3) OVER (ORDER BY avg(datetime2-datetime1) DESC) AS frequency_group,
    avg(datetime2-datetime1) AS avg_days_between_transaction -- среднее количество дней между покупками
FROM (
    SELECT
        id, 
        count(e.transaction_id) AS total_transaction,
        "date"::timestamp+"time"::time AS datetime1,
        Lead("date"::timestamp+"time"::time, 1) OVER (partition BY id ORDER BY "date"::timestamp+"time"::time) AS datetime2
    FROM fantasy.events AS e
    WHERE amount<>0
    GROUP BY id, "date","time") AS not_null
WHERE (datetime2 IS NOT NULL)
GROUP BY id
HAVING count(total_transaction)>=25
),
--
payer_user AS ( --платящие игроки
SELECT
    id,
    count(*) AS count_payer
FROM total_transaction
LEFT JOIN fantasy.users u USING(id)
WHERE payer=1
GROUP BY id),
bayer_user AS (--покупающие игроки
SELECT 
    id,
    count(DISTINCT id) AS count_bayer
FROM total_transaction
GROUP BY 
    id),
from_users_events AS (
SELECT 
    DISTINCT id,
    count(DISTINCT id) AS payer_bayer_count
FROM fantasy.events
JOIN fantasy.users using(id)
WHERE amount<>0 and payer=1
GROUP BY id
)
SELECT 
    CASE 
	    WHEN frequency_group=1 THEN 'Высокая частота'
	    WHEN frequency_group=2 THEN 'Умеренная частота'
	    WHEN frequency_group=3 THEN 'Низкая частота'
	    ELSE 'Без категории'
    END AS category, --категория игрока по частоте покупок
    sum(count_bayer) AS count_bayer, --количество игроков, совершивших покупки
    sum(count_payer) AS count_payer, --платящие игроки
    SUM(payer_bayer_count)/SUM(count_bayer) AS part_payer, -- доля платящих
    sum(count_total_transaction)/sum(count_bayer) AS avg_transaction, --среднее количество покупок
    EXTRACT('day' FROM (avg(avg_days_between_transaction))) AS avg_days_between_transaction
FROM total_transaction
LEFT JOIN payer_user using(id)
LEFT JOIN bayer_user using(id)
LEFT JOIN from_users_events USING(id)
GROUP BY frequency_group;


