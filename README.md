# Montañas del Centro de México: Análisis de Incendios y Muestreo

Este repositorio contiene las rutinas de código, datos base y resultados finales para replicar el análisis espacial de incendios forestales y la caracterización de sitios de muestreo en la región de las Montañas del Centro de México.

## 📋 Contenido del Repositorio

| Archivo / Carpeta | Descripción |
| :--- | :--- |
| `AnálisisdedatosMCM.R` | Script principal de análisis estadístico y espacial. |
| `BorradorMapaInteractivo.R` | Script para generar el mapa interactivo (HTML) de polígonos y sitios. |
| `TablasdeResultados.R` | Rutinas para la generación de tablas resumen. |
| `DatosEMCM.csv` | Datos crudos del estudio. |
| `sitios_y_controles_coordenadas.csv` | Coordenadas geográficas de los sitios de muestreo y controles. |
| `gadm/` | Capas geoespaciales base (límites administrativos de México). |
| `figuras/` | Resultados finales en formato de imagen (correlaciones, pruebas estadísticas, etc.). |

## 🔥 Polígonos de Incendios

Los polígonos de incendios utilizados en el análisis se obtuvieron de fuentes oficiales (CONAFOR/IDEFOR) y fueron procesados mediante los scripts incluidos. Para visualizar la distribución espacial de los incendios, consulta el **Mapa Interactivo**.

- **Visualización estática:** Puedes encontrar una vista previa de los polígonos en la carpeta `figuras/` (si se ha generado alguna imagen al respecto).
- **Datos fuente:** Los archivos de polígonos (shapefiles) no se incluyen directamente en el repositorio debido a su tamaño, pero se detalla en el script `AnálisisdedatosMCM.R` la ruta o el método de descarga para replicar el proceso.

## 📍 Localización de Sitios de Muestreo

La ubicación exacta de los sitios de muestreo y los controles se encuentra en el archivo:

**`sitios_y_controles_coordenadas.csv`**

Este archivo contiene las columnas de longitud, latitud y la categoría (sitio o control) para cada punto. Puedes visualizar estos puntos de dos maneras:

1.  **Mapa Interactivo (HTML):** Abre el archivo `mapa_interactivo.html` (generado con `BorradorMapaInteractivo.R`) en cualquier navegador. Allí podrás hacer zoom, clicar sobre los puntos y ver los polígonos de incendios superpuestos.
2.  **Vista previa en el README:** A continuación se muestra un ejemplo de cómo se verían los sitios (puedes insertar una captura de pantalla aquí si lo deseas).

## 📊 Resultados Finales

Todos los productos gráficos del análisis (correlaciones, pruebas de Mann-Whitney, modelos de regresión logística binaria, tablas de contingencia, etc.) se encuentran en la carpeta **`figuras/`**. 

Algunos de los archivos destacados son:
- `CorSpearman.png`: Matriz de correlación de Spearman.
- `ManWhitney.png`: Resultados de la prueba U de Mann-Whitney.
- `ModRegLogBinFinal.png`: Ajuste del modelo de regresión logística binaria.
- `TabladeContigenciaMejorada.png`: Tabla de contingencia mejorada.

Puedes insertar estas imágenes directamente en este README usando la sintaxis de Markdown:

```markdown
![Correlación Spearman](figuras/CorSpearman.png)
