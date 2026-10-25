# Predicción de recompra a 60 días - The Look

El objetivo es identificar qué clientes tienen alta probabilidad de volver a comprar dentro de los 60 días posteriores a su primera compra. Se considera recompra una nueva orden, sin importar la cantidad de ítems que contenga.

Notebook en Colab (solo lectura): https://colab.research.google.com/drive/1AW9z5wZRqc7Q68y96YCuHb3LjKGV7iC7?usp=sharing

## Contenido del repositorio

- `caso_recompra_the_look_juanureta.ipynb`: notebook completo (calidad de datos, tabla base, análisis exploratorio, modelo y predicciones)
- `sql/`: consultas de BigQuery (`01_checks_calidad.sql` y `02_base_modelo.sql`)
- `predicciones_muestra.csv`: `user_id` y probabilidad de recompra de los clientes del periodo de prueba
- `arquitectura_aws.png`: diagrama de la arquitectura propuesta en AWS

## Cómo ejecutarlo

Abrir el notebook en Colab y ejecutar la opción Entorno de ejecución > Ejecutar todo. El notebook solicita autenticarse con una cuenta de Google que tenga acceso al proyecto `bussiness-case-tyc` en BigQuery.

Los parámetros (proyecto, dataset de salida, horizonte de 60 días y fecha de corte) se definen en `CONFIG`. Si la fecha de corte es `None`, se utiliza la fecha de la última orden registrada. La tabla base se crea con `CREATE OR REPLACE`, por lo que ejecutarlo nuevamente no duplica resultados.

Librerías utilizadas: pandas, numpy, matplotlib, scikit-learn, google-cloud-bigquery y db-dtypes (incluidas en Colab).

## Supuestos

- La primera compra corresponde a la primera orden válida de cada cliente. Se excluyeron las órdenes canceladas; las devueltas se mantuvieron, ya que el cliente sí realizó la compra.
- Las variables utilizan únicamente información disponible hasta la primera compra. No se emplearon `shipped_at`, `delivered_at` ni `returned_at`, y los eventos web considerados son solo los anteriores a la compra.
- Los clientes con menos de 60 días de historia se excluyeron, porque aún no es posible saber si recompran.
- Los datos se separaron por fecha: se entrenó con los clientes más antiguos y se evaluó con los últimos 3 meses con etiqueta completa, dejando 60 días de separación entre ambos periodos.

## Resultados

La tasa de recompra global es 6.27% (63,538 clientes). En el periodo de prueba asciende a 14.56%, debido a que la recompra se acelera en 2024.

Al contactar al 20% de clientes con mayor puntaje, en el periodo de prueba:

- Azar: precision 14.6%, recall 20.0%
- Regla simple (compra pronto tras registrarse): precision 33.0%, recall 45.3%, PR AUC 0.298
- Regresión logística: precision 30.8%, recall 42.3%, PR AUC 0.268

El modelo duplica el desempeño del azar, pero no supera la regla simple. Las limitaciones y posibles mejoras se detallan al final del notebook.
