--Определить регионы с наибольшим количеством зарегистрированных доноров.
SELECT region, 
    COUNT(id) donor_count
FROM donorsearch.user_anon_data
GROUP BY region 
ORDER BY donor_count DESC
LIMIT 10;

--Изучить динамику общего количества донаций в месяц за 2022 и 2023 годы.
SELECT DATE_TRUNC('month', donation_date)::date date,
    COUNT(id)
FROM donorsearch.donation_anon
WHERE EXTRACT(year from donation_date)=2022
GROUP BY date
UNION 
SELECT DATE_TRUNC('month', donation_date)::date date, 
    COUNT(id)
FROM donorsearch.donation_plan
WHERE EXTRACT(year FROM donation_date)=2023
GROUP BY date
ORDER BY date;

--Определить наиболее активных доноров в системе, учитывая только данные о зарегистрированных и подтвержденных донациях.
SELECT id, 
    confirmed_donations as count 
FROM donorsearch.user_anon_data
ORDER BY count DESC
LIMIT 10;

--Оценить, как система бонусов влияет на зарегистрированные в системе донации.
WITH donor_activity AS
  (SELECT u.id,
          u.confirmed_donations,
          COALESCE(b.user_bonus_count, 0) AS user_bonus_count
   FROM donorsearch.user_anon_data u
   LEFT JOIN donorsearch.user_anon_bonus b ON u.id = b.user_id)
SELECT CASE
           WHEN user_bonus_count > 0 THEN 'Получили бонусы'
           ELSE 'Не получали бонусы'
       END AS статус_бонусов,
       COUNT(id) AS количество_доноров,
       AVG(confirmed_donations) AS среднее_количество_донаций
FROM donor_activity
GROUP BY статус_бонусов;

--Исследовать вовлечение новых доноров через социальные сети, учитывая только тех, кто совершил хотя бы одну донацию. Узнать, сколько по каким каналам пришло доноров, и среднее количество донаций по каждому каналу.
SELECT CASE
		WHEN autho_vk THEN 'VK'
		WHEN autho_ok THEN 'ok'
		WHEN autho_tg THEN 'tg'
		WHEN autho_yandex THEN 'yandex'
		WHEN autho_google THEN 'google'
		ELSE 'not autho'
	END AS соц_сеть,
	COUNT(id), 
	AVG(confirmed_donations) as avg
	FROM donorsearch.user_anon_data uad 
	WHERE confirmed_donations>=1
	GROUP BY соц_сеть
	ORDER BY count(id) DESC;

--Сравнить активность однократных доноров со средней активностью повторных доноров.	
WITH donor_activity AS (
    SELECT user_id,
        COUNT(*) AS total_donations,
        (MAX(donation_date) - MIN(donation_date)) AS activity_duration_days,
        (MAX(donation_date) - MIN(donation_date)) / COUNT(*) AS avg_days_between_donations,
        EXTRACT(YEAR FROM MIN(donation_date)) AS Первый_год_донации,
        EXTRACT(YEAR FROM AGE(CURRENT_DATE, MIN(donation_date))) AS Среднее_количество_лет_после_первой_донации
    FROM donorsearch.donation_anon
    GROUP BY user_id
)
SELECT Первый_год_донации,
       CASE 
           WHEN total_donations=1 THEN '1 донация'
           WHEN total_donations BETWEEN 2 AND 3 THEN '2-3 донации'
           WHEN total_donations BETWEEN 4 AND 5 THEN '4-5 донаций'
           ELSE '6 и более донаций'
       END AS Количество_донаций,
       COUNT(user_id) AS Количество_доноров,
       AVG(total_donations) AS Среднее_количество_дотаций,
       AVG(activity_duration_days) AS Среднее_количество_дней,
       AVG(avg_days_between_donations) AS Среднее_количество_дней_между_донациями,
       AVG(Среднее_количество_лет_после_первой_донации) AS Среднее_количество_лет_после_первой_донации
FROM donor_activity
GROUP BY Первый_год_донации, Количество_донаций
ORDER BY Первый_год_донации, Количество_донаций;

--Сравнить данные о планируемых донациях с фактическими данными, чтобы оценить эффективность планирования.
WITH plan AS
    (SELECT DISTINCT dp.user_id,
		dp.donation_date, 
		dp.donation_type AS Тип_донации
FROM donorsearch.donation_plan dp),
actual AS
(SELECT DISTINCT da.user_id,
		da.donation_date, 
		da.donation_type AS Тип_донации
FROM donorsearch.donation_anon da),
planned_vs_actual AS (
  SELECT
    pd.user_id,
    pd.donation_date AS planned_date,
    pd.Тип_донации,
    CASE WHEN ad.user_id IS NOT NULL THEN 1 ELSE 0 END AS completed
  FROM plan pd
  LEFT JOIN actual ad ON pd.user_id = ad.user_id AND pd.donation_date = ad.donation_date
)
SELECT  Тип_донации, 
		COUNT(*) AS total_planned_donations,
  		SUM(completed) AS completed_donations,
		ROUND(SUM(completed) * 100.0 / COUNT(*), 2) AS completion_rate
FROM planned_vs_actual
GROUP BY Тип_донации;
