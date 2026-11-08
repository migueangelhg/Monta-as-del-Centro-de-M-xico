library(terra)
library(sf)
library(geodata)
library(leaflet)
library(htmlwidgets)

# ============================================================
# 1. CARGAR DATOS
# ============================================================

# --- Polígono principal ---
malinche <- read_sf("Poligonanpsmex/PolMalinche/WDPA_WDOECM_Sep2026_Public_212_shp-polygons.shp") |>
  st_geometry() |>
  st_sf() |>
  st_transform(4326)

# --- GADM: país (nivel 0), estados (1), municipios (2) ---
ruta_gadm <- "c:/Users/31628/Documents/MontañasdelCentro/"

mex_pais <- gadm("MEX", level = 0, path = ruta_gadm) |> st_as_sf() |> st_transform(4326)
mex_edos <- gadm("MEX", level = 1, path = ruta_gadm) |> st_as_sf() |> st_transform(4326)
mex_muns <- gadm("MEX", level = 2, path = ruta_gadm) |> st_as_sf() |> st_transform(4326)

# ============================================================
# 2. BOUNDING BOX CON MARGEN
# ============================================================
bb <- st_bbox(malinche)
m  <- 0.15 * max(as.numeric(bb["xmax"] - bb["xmin"]),
                 as.numeric(bb["ymax"] - bb["ymin"]))

bbox_poly <- st_as_sfc(st_bbox(
  c(xmin = as.numeric(bb["xmin"]) - m,
    ymin = as.numeric(bb["ymin"]) - m,
    xmax = as.numeric(bb["xmax"]) + m,
    ymax = as.numeric(bb["ymax"]) + m),
  crs = 4326))

# ============================================================
# 3. RECORTAR EDOS Y MUNS AL AOI (opcional, acelera el render)
# ============================================================
aoi <- st_sf(geometry = bbox_poly)

mex_edos_aoi <- st_intersection(mex_edos, aoi)
mex_muns_aoi <- st_intersection(mex_muns, aoi)

# ============================================================
# 4. MAPA INTERACTIVO
# ============================================================
mapa <- leaflet() |>
  
  # --- Basemaps (se alternan desde el control) ---
  addProviderTiles(providers$OpenStreetMap,     group = "OSM") |>
  addProviderTiles(providers$Esri.WorldImagery, group = "Satélite") |>
  addProviderTiles(providers$CartoDB.Positron,  group = "Claro") |>
  
  # --- Nivel 0: País ---
  addPolygons(
    data        = mex_pais,
    color       = "grey20",
    weight      = 1.5,
    fillColor   = "grey80",
    fillOpacity = 0.15,
    group       = "Nivel 0 — País",
    label       = "México"
  ) |>
  
  # --- Nivel 1: Estados ---
  addPolygons(
    data        = mex_edos_aoi,
    color       = "grey40",
    weight      = 1,
    fillColor   = "orange",
    fillOpacity = 0.08,
    group       = "Nivel 1 — Estados",
    label       = ~NAME_1,
    highlightOptions = highlightOptions(
      weight = 2, color = "black", fillOpacity = 0.2, bringToFront = TRUE
    )
  ) |>
  
  # --- Nivel 2: Municipios ---
  addPolygons(
    data        = mex_muns_aoi,
    color       = "grey60",
    weight      = 0.5,
    fillColor   = "yellow",
    fillOpacity = 0.05,
    group       = "Nivel 2 — Municipios",
    label       = ~NAME_2,
    highlightOptions = highlightOptions(
      weight = 1.5, color = "black", fillOpacity = 0.15, bringToFront = TRUE
    )
  ) |>
  
  # --- Polígono principal ---
  addPolygons(
    data        = malinche,
    color       = "darkred",
    weight      = 2,
    fillColor   = "red",
    fillOpacity = 0.5,
    group       = "La Malinche",
    label       = "La Malinche",
    popup       = "<b>La Malinche</b><br>Área Natural Protegida",
    highlightOptions = highlightOptions(
      weight = 3, color = "black", fillOpacity = 0.7, bringToFront = TRUE
    )
  ) |>
  
  # --- Bounding box ---
  addPolygons(
    data        = bbox_poly,
    color       = "blue",
    weight      = 2,
    dashArray   = "5,5",
    fill        = FALSE,
    group       = "Bounding box"
  ) |>
  
  # --- Vista inicial al bbox ---
  fitBounds(
    lng1 = as.numeric(bb["xmin"]) - m,
    lat1 = as.numeric(bb["ymin"]) - m,
    lng2 = as.numeric(bb["xmax"]) + m,
    lat2 = as.numeric(bb["ymax"]) + m
  ) |>
  
  # --- Control de capas ---
  addLayersControl(
    baseGroups    = c("OSM", "Satélite", "Claro"),
    overlayGroups = c(
      "Nivel 0 — País",
      "Nivel 1 — Estados",
      "Nivel 2 — Municipios",
      "La Malinche",
      "Bounding box"
    ),
    options = layersControlOptions(collapsed = FALSE)
  ) |>
  
  # --- Extras ---
  addScaleBar(position = "bottomleft") |>
  addMiniMap(toggleDisplay = TRUE, position = "bottomright")

# ============================================================
# 5. MOSTRAR Y GUARDAR
# ============================================================
mapa

saveWidget(mapa, "malinche_interactivo.html", selfcontained = TRUE)