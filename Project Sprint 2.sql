SELECT *
FROM public.parcing_table
LIMIT 15;


--Определите диапазон заработных плат в общем, а именно средние значения, минимумы и максимумы нижних и верхних порогов зарплаты
SELECT ROUND(AVG(salary_from),0) AS avg_salary_from,
       ROUND(AVG(salary_to),0) AS avg_salary_to,
       MIN(salary_from) AS min_salary_from,
       MIN(salary_to) AS min_salary_to,
       max(salary_from) AS max_salary_from,    
       max(salary_to) AS max_salary_to
FROM public.parcing_table;

--Выявите регионы и компании, в которых сосредоточено наибольшее количество вакансий
SELECT area,
       COUNT(*) AS num_vacancies
FROM public.parcing_table
GROUP BY area
ORDER BY num_vacancies DESC
LIMIT 5;

--Проанализируйте, какие преобладают типы занятости, а также графики работы.
SELECT employer, COUNT(*) AS quantity_vac
FROM public.parcing_table
GROUP BY employer
ORDER BY quantity_vac DESC
LIMIT 10;

--Распределение по типу занятости
SELECT employment, COUNT(*) AS quantity_emp
FROM public.parcing_table
GROUP BY employment 
ORDER BY quantity_emp DESC
LIMIT 10;

--Распределение по графику работы
SELECT schedule, COUNT(*) AS quantity_sched
FROM public.parcing_table
GROUP BY schedule 
ORDER BY quantity_sched DESC
LIMIT 10;

--Распределение по типу занятости и графику работы
SELECT schedule, employment, COUNT(*) AS quantity
FROM public.parcing_table
GROUP BY schedule, employment 
ORDER BY quantity DESC
LIMIT 10;

--Распределение по грейдам
SELECT experience, COUNT(*) AS quantity_name
FROM public.parcing_table
GROUP BY experience 
ORDER BY quantity_name DESC;

--Изучите распределение грейдов (Junior, Middle, Senior) среди аналитиков данных и системных аналитиков.
--Используем подзапрос в SELECT для нахождения общего количества позиций аналитиков  
SELECT experience,
       COUNT(*) AS num_vacancies,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) 
FROM public.parcing_table 
WHERE name LIKE '%Аналитик данных%' 
   OR name LIKE '%Системный аналитик%'), 2) AS percent_vacancies
FROM public.parcing_table
WHERE name LIKE '%Аналитик данных%' 
   OR name LIKE '%Системный аналитик%'
GROUP BY experience
ORDER BY percent_vacancies DESC;

--Выявите основных работодателей, предлагаемые зарплаты и условия труда для аналитиков.
SELECT employer, ROUND(AVG(salary_from),2) AS AVG_salary_from, ROUND(AVG(salary_to),2) AS AVG_salary_to, schedule, employment, COUNT(*) AS count_vac
FROM public.parcing_table
WHERE name LIKE '%Аналитик данных%' OR name LIKE '%Системный аналитик%'
GROUP BY employer, schedule, employment
ORDER BY count_vac DESC
LIMIT 5;

--Определите наиболее востребованные навыки (как жёсткие, так и мягкие) для различных грейдов и позиций
SELECT key_skills_1, COUNT(*) AS count_skills
FROM public.parcing_table
GROUP BY key_skills_1
ORDER BY count_skills DESC
LIMIT 10;




