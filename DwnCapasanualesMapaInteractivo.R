library(sf)
library(leaflet)
library(htmlwidgets)


# --- FIX para el error 403 de OpenStreetMap ---
L.TileLayer.prototype.options.referrerPolicy = 'strict-origin-when-cross-origin';

# ============================================================
# 1. CARGAR POLÍGONO
# ============================================================
malinche <- read_sf("Poligonanpsmex/PolMalinche/WDPA_WDOECM_Sep2026_Public_212_shp-polygons.shp") |>
  st_geometry() |>
  st_sf() |>
  st_transform(4326)

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
# 3. MAPA INTERACTIVO
# ============================================================
mapa <- leaflet() |>
  
  # --- Basemaps ---
  addProviderTiles(providers$OpenStreetMap,     group = "OSM") |>
  addProviderTiles(providers$Esri.WorldImagery, group = "Satélite") |>
  addProviderTiles(providers$CartoDB.Positron,  group = "Claro") |>
  
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
    overlayGroups = c("La Malinche", "Bounding box"),
    options       = layersControlOptions(collapsed = FALSE)
  ) |>
  
  # --- Extras ---
  addScaleBar(position = "bottomleft") |>
  addMiniMap(toggleDisplay = TRUE, position = "bottomright")

# ============================================================
# 4. MOSTRAR Y GUARDAR
# ============================================================
mapa

saveWidget(mapa, "malinche_interactivo.html", selfcontained = TRUE)


########### Sobrelape de poligonos de incendio ###########


#install.packages("ows4R")
library(ows4R)
library(sf)

wfs <- WFSClient$new(
  url = "https://idefor.cnf.gob.mx/geoserver/ows",
  serviceVersion = "1.1.0"
)

# Ver todas las capas
capas <- wfs$getCapabilities()$findFeatureTypes()
print(capas)






caps <- wfs$getCapabilities()

# Opción A: Listar TODAS las capas (puede ser largo)
todas_las_capas <- caps$getFeatureTypes()
print(todas_las_capas)

# Opción B: Buscar directamente por nombre (ej. probando "incendios")
capa <- caps$findFeatureTypeByName("incendios")
print(capa)


#####################
###################


library(xml2)
library(sf)
library(dplyr)

# --- Descargar el GetCapabilities ---
url_caps <- "https://idefor.cnf.gob.mx/geoserver/ows?service=WFS&version=1.1.0&request=GetCapabilities"
xml_file <- tempfile(fileext = ".xml")
download.file(url_caps, xml_file, mode = "wb", quiet = TRUE)

xml <- read_xml(xml_file)
ns  <- xml_ns(xml)

# --- Extraer Name + Title ---
nombres <- xml_text(xml_find_all(xml, ".//d1:FeatureType/d1:Name",  ns = ns))
titulos <- xml_text(xml_find_all(xml, ".//d1:FeatureType/d1:Title", ns = ns))

capas_df <- data.frame(Name  = nombres,
                       Title = titulos,
                       stringsAsFactors = FALSE) |>
  filter(grepl("Concentrado Nacional de Polígonos de Incendios",
               Title, ignore.case = TRUE)) |>
  mutate(Anio = as.integer(sub(".*?(\\d{4}).*", "\\1", Name))) |>
  filter(Anio >= 2020) |>
  arrange(Anio, Name) |>
  # Quedarnos solo con una capa por año (la última alfabéticamente)
  group_by(Anio) |>
  slice_tail(n = 1) |>
  ungroup()

print(capas_df, row.names = FALSE)



# --- 3.2 Función de descarga con filtro BBOX ---
descargar_incendios <- function(capa, bbox, anio) {
  url <- paste0(
    "https://idefor.cnf.gob.mx/geoserver/ows?",
    "service=WFS&version=1.1.0&request=GetFeature",
    "&typeName=",
    capa,
    "&outputFormat=application/json",
    "&bbox=", paste(bbox, collapse = ","), ",EPSG:4326"
  )
  message("→ ", anio, ": ", capa)
  out <- tryCatch(read_sf(url),
                  error = function(e) { warning(conditionMessage(e)); NULL })
  if (!is.null(out) && nrow(out) > 0) out$ANIO_DESC <- anio
  out
}

bb_exp <- c(
  xmin = as.numeric(bb["xmin"]) - m,
  ymin = as.numeric(bb["ymin"]) - m,
  xmax = as.numeric(bb["xmax"]) + m,
  ymax = as.numeric(bb["ymax"]) + m
)



# --- 3.4 Descargar todos los años ---
inc_lista_limpia <- lapply(inc_lista, function(x) {
  if (is.null(x)) return(NULL)
  x |>
    mutate(across(
      where(~ inherits(.x, c("POSIXct", "POSIXt", "Date", "difftime"))),
      ~ as.character(.x)
    ))
})

inc_todos <- bind_rows(Filter(Negate(is.null), inc_lista_limpia))

# Recortar a La Malinche y arreglar geometrías inválidas
inc_mal <- inc_todos |>
  st_intersection(malinche) |>
  st_make_valid()

# Ver cuántos quedan por año
inc_mal |>
  st_drop_geometry() |>
  count(ANIO_DESC, name = "n") |>
  print()


# ============================================================
# 5. RECONVERTIR TIPOS Y PREPARAR DATOS PARA EL MAPA
# ============================================================
inc_mal <- inc_mal |>
  mutate(
    AREA_HA   = suppressWarnings(as.numeric(AREA_HA)),
    ANIO_DESC = as.integer(ANIO_DESC)
  )



# ============================================================
# 6. MAPA INTERACTIVO CON INCENDIOS POR AÑO
# ============================================================
anios   <- sort(unique(inc_mal$ANIO_DESC))
paleta  <- c("#e41a1c", "#ff7f00", "#ffd700",
             "#4daf4a", "#377eb8", "#984ea3",
             "#a65628", "#f781bf")
colores <- colorFactor(palette = paleta, domain = anios)

# --- Mapa base (con basemaps, La Malinche y bbox) ---
mapa <- leaflet() |>
  
  # --- Basemaps ---
  addProviderTiles(providers$OpenStreetMap,     group = "OSM") |>
  addProviderTiles(providers$Esri.WorldImagery, group = "Satélite") |>
  addProviderTiles(providers$CartoDB.Positron,  group = "Claro") |>
  
  # --- Polígono principal ---
  addPolygons(
    data        = malinche,
    color       = "darkred",
    weight      = 2,
    fillColor   = "red",
    fillOpacity = 0.15,
    group       = "La Malinche",
    label       = "La Malinche",
    popup       = "<b>La Malinche</b><br>Área Natural Protegida",
    highlightOptions = highlightOptions(
      weight = 3, color = "black", fillOpacity = 0.4, bringToFront = TRUE
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
  )

# --- Una capa de incendios por año ---
for (a in anios) {
  datos_a <- inc_mal[inc_mal$ANIO_DESC == a, ]
  
  mapa <- mapa |>
    addPolygons(
      data        = datos_a,
      color       = ~colores(ANIO_DESC),
      weight      = 1,
      fillColor   = ~colores(ANIO_DESC),
      fillOpacity = 0.5,
      group       = paste("Incendios", a),
      label       = ~paste0("Incendio ", ANIO_DESC,
                            " | ", MUNICIPIO,
                            " | ", round(AREA_HA, 1), " ha"),
      popup       = ~paste0(
        "<b>Incendio ", ANIO_DESC, "</b><br>",
        "<b>Clave:</b> ", CLAVEINC, "<br>",
        "<b>Municipio:</b> ", MUNICIPIO, "<br>",
        "<b>Causa:</b> ", CAUSA, "<br>",
        "<b>Superficie:</b> ", round(AREA_HA, 2), " ha"
      ),
      highlightOptions = highlightOptions(
        weight = 2, color = "black",
        fillOpacity = 0.75, bringToFront = TRUE
      )
    )
}

# --- Vista, control de capas y extras ---
mapa <- mapa |>
  fitBounds(
    lng1 = as.numeric(bb["xmin"]) - m,
    lat1 = as.numeric(bb["ymin"]) - m,
    lng2 = as.numeric(bb["xmax"]) + m,
    lat2 = as.numeric(bb["ymax"]) + m
  ) |>
  addLayersControl(
    baseGroups    = c("OSM", "Satélite", "Claro"),
    overlayGroups = c("La Malinche", "Bounding box",
                      paste("Incendios", anios)),
    options       = layersControlOptions(collapsed = FALSE)
  ) |>
  addScaleBar(position = "bottomleft") |>
  addMiniMap(toggleDisplay = TRUE, position = "bottomright")

# ============================================================
# 7. MOSTRAR Y GUARDAR
# ============================================================
mapa


saveWidget(mapa, "malinche_incendios_2020_2025.html",
           selfcontained = TRUE)



################# Calculo de la severidad de incendios #########


# Instalación (solo una vez)
install.packages("sen2r")

library(sen2r)


################### Google Earth ###################

# 1. Instalar el paquete rgee desde CRAN
install.packages("rgee")

# 2. Instalar y configurar el entorno de Python y las dependencias de Earth Engine
library(rgee)
ee_install() # Esto instalará Miniconda, Python y la API de earthengine-api si no los tienes.








