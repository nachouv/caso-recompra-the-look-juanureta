-- 02_base_modelo.sql
-- Tabla base del modelo: 1 fila por cliente
-- Etiqueta: recompra (otra ORDEN) dentro de los 60 dias siguientes a la primera orden
-- Supuestos:
--   * Se excluyen ordenes 'Cancelled'; 'Returned' se mantiene (el cliente si compro)
--   * Features solo con informacion disponible hasta la primera compra (sin fuga)
--   * No se usan shipped_at / delivered_at / returned_at (informacion posterior)
--   * Eventos web: solo antes de la primera compra, sin 'purchase' ni 'cancel'
--   * Clientes sin 60 dias completos de historia quedan fuera del entrenamiento

CREATE OR REPLACE TABLE `bussiness-case-tyc.juan_ureta.base_modelo` AS
WITH params AS (
  SELECT MAX(created_at) AS max_ts
  FROM `bussiness-case-tyc.bussiness_case_ecommerce.orders`
),
valid_orders AS (
  SELECT order_id, user_id, created_at
  FROM `bussiness-case-tyc.bussiness_case_ecommerce.orders`
  WHERE status != 'Cancelled'
    AND order_id IS NOT NULL AND user_id IS NOT NULL AND created_at IS NOT NULL
),
first_order AS (
  SELECT * EXCEPT(rn) FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at, order_id) AS rn
    FROM valid_orders
  ) WHERE rn = 1
),
label AS (
  SELECT f.user_id, f.order_id, f.created_at AS first_order_ts,
         IF(COUNT(o.order_id) > 0, 1, 0) AS repurchase_60d
  FROM first_order f
  LEFT JOIN valid_orders o
    ON o.user_id = f.user_id
   AND o.order_id != f.order_id
   AND o.created_at > f.created_at
   AND o.created_at <= TIMESTAMP_ADD(f.created_at, INTERVAL 60 DAY)
  GROUP BY 1, 2, 3
),
items_first AS (
  SELECT oi.order_id,
         COUNT(*) AS n_items,
         SUM(oi.sale_price) AS order_value,
         SUM(oi.sale_price - p.cost) AS order_margin,
         COUNT(DISTINCT p.category) AS n_categories,
         COUNT(DISTINCT p.brand) AS n_brands,
         ARRAY_AGG(p.department IGNORE NULLS ORDER BY oi.sale_price DESC LIMIT 1)[SAFE_OFFSET(0)] AS top_department,
         ARRAY_AGG(p.category IGNORE NULLS ORDER BY oi.sale_price DESC LIMIT 1)[SAFE_OFFSET(0)] AS top_category
  FROM `bussiness-case-tyc.bussiness_case_ecommerce.order_items` oi
  LEFT JOIN `bussiness-case-tyc.bussiness_case_ecommerce.products` p ON p.id = oi.product_id
  WHERE oi.order_id IN (SELECT order_id FROM first_order)
  GROUP BY 1
),
events_pre AS (
  SELECT f.user_id,
         COUNT(DISTINCT e.session_id) AS n_sessions_pre,
         COUNT(*) AS n_events_pre,
         COUNTIF(e.event_type = 'product') AS n_product_views_pre,
         COUNTIF(e.event_type = 'cart') AS n_cart_events_pre
  FROM first_order f
  JOIN `bussiness-case-tyc.bussiness_case_ecommerce.events` e
    ON e.user_id = f.user_id
   AND e.created_at < f.created_at
   AND e.event_type NOT IN ('purchase', 'cancel')
  GROUP BY 1
)
SELECT l.user_id, l.order_id AS first_order_id, l.first_order_ts, l.repurchase_60d,
       i.n_items, i.order_value, i.order_margin, i.n_categories, i.n_brands,
       i.top_department, i.top_category,
       u.age, u.gender, u.country, u.traffic_source,
       TIMESTAMP_DIFF(l.first_order_ts, u.created_at, DAY) AS days_signup_to_purchase,
       COALESCE(ev.n_sessions_pre, 0) AS n_sessions_pre,
       COALESCE(ev.n_events_pre, 0) AS n_events_pre,
       COALESCE(ev.n_product_views_pre, 0) AS n_product_views_pre,
       COALESCE(ev.n_cart_events_pre, 0) AS n_cart_events_pre
FROM label l
JOIN `bussiness-case-tyc.bussiness_case_ecommerce.users` u ON u.id = l.user_id
LEFT JOIN items_first i ON i.order_id = l.order_id
LEFT JOIN events_pre ev ON ev.user_id = l.user_id
CROSS JOIN params p
WHERE l.first_order_ts <= TIMESTAMP_SUB(p.max_ts, INTERVAL 60 DAY);

-- Verificacion de la tabla (esperado: filas = clientes)
SELECT COUNT(*) AS filas,
       COUNT(DISTINCT user_id) AS clientes,
       ROUND(AVG(repurchase_60d), 4) AS tasa_recompra,
       MIN(first_order_ts) AS primera_compra_min,
       MAX(first_order_ts) AS primera_compra_max,
       COUNTIF(order_value IS NULL) AS sin_items
FROM `bussiness-case-tyc.juan_ureta.base_modelo`;
