-- 01_checks_calidad.sql
-- Exploracion inicial y controles de calidad sobre las tablas fuente
-- Proyecto: bussiness-case-tyc | Dataset origen: bussiness_case_ecommerce

-- 1) Tipos de evento web
SELECT event_type, COUNT(*) AS n
FROM `bussiness-case-tyc.bussiness_case_ecommerce.events`
GROUP BY 1 ORDER BY 2 DESC;

-- 2) Estados de orden (se excluye solo 'Cancelled')
SELECT status, COUNT(*) AS n
FROM `bussiness-case-tyc.bussiness_case_ecommerce.orders`
GROUP BY 1 ORDER BY 2 DESC;

-- 3) Controles de calidad (resultado esperado: todos en 0)
SELECT 'orders duplicadas por order_id' AS check_name,
       COUNT(*) - COUNT(DISTINCT order_id) AS n
FROM `bussiness-case-tyc.bussiness_case_ecommerce.orders`
UNION ALL
SELECT 'orders con claves o fecha nulas',
       COUNTIF(user_id IS NULL OR created_at IS NULL OR order_id IS NULL)
FROM `bussiness-case-tyc.bussiness_case_ecommerce.orders`
UNION ALL
SELECT 'orders sin usuario en users',
       COUNT(*)
FROM `bussiness-case-tyc.bussiness_case_ecommerce.orders` o
LEFT JOIN `bussiness-case-tyc.bussiness_case_ecommerce.users` u ON u.id = o.user_id
WHERE u.id IS NULL
UNION ALL
SELECT 'orders sin items',
       COUNT(*)
FROM `bussiness-case-tyc.bussiness_case_ecommerce.orders` o
LEFT JOIN (SELECT DISTINCT order_id FROM `bussiness-case-tyc.bussiness_case_ecommerce.order_items`) oi
  ON oi.order_id = o.order_id
WHERE oi.order_id IS NULL
UNION ALL
SELECT 'items sin producto',
       COUNT(*)
FROM `bussiness-case-tyc.bussiness_case_ecommerce.order_items` oi
LEFT JOIN `bussiness-case-tyc.bussiness_case_ecommerce.products` p ON p.id = oi.product_id
WHERE p.id IS NULL;
