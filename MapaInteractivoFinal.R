# ============================================================
# MAPA INTERACTIVO: LA MALINCHE - INCENDIOS + SITIOS DE MUESTREO
# Genera: malinche_incendios_2020_2025.html
# Mapas base: Satélite y Topográfico (Esri). Sin OSM, sin minimapa.
# ============================================================

# --- 0. Paquetes ---
pkgs <- c("sf", "leaflet", "htmlwidgets", "dplyr", "xml2")
for (p in pkgs) if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
library(sf); library(leaflet); library(htmlwidgets); library(dplyr); library(xml2)

# --- 1. Poligono del ANP ---
malinche <- read_sf("Poligonanpsmex/PolMalinche/WDPA_WDOECM_Sep2026_Public_212_shp-polygons.shp") |>
  st_geometry() |> st_sf() |> st_transform(4326)

# --- 2. Bounding box ---
bb <- st_bbox(malinche)
m  <- 0.15 * max(as.numeric(bb["xmax"] - bb["xmin"]),
                 as.numeric(bb["ymax"] - bb["ymin"]))
bb_exp <- c(
  xmin = as.numeric(bb["xmin"]) - m,
  ymin = as.numeric(bb["ymin"]) - m,
  xmax = as.numeric(bb["xmax"]) + m,
  ymax = as.numeric(bb["ymax"]) + m
)
bbox_poly <- st_as_sfc(st_bbox(bb_exp, crs = 4326))

# ============================================================
# --- 3. Verificacion del cache ---
# ============================================================
anios_objetivo <- 2020:2025

cat("\n=== ESTADO DEL CACHE ===\n")
for (a in anios_objetivo) {
  f <- sprintf("cache_wfs/incendios_%d.geojson", a)
  if (file.exists(f)) {
    kb <- round(file.size(f) / 1024, 1)
    cat("  ", a, ": OK (", kb, " KB)\n", sep = "")
  } else {
    cat("  ", a, ": FALTA\n", sep = "")
  }
}

faltan <- anios_objetivo[!file.exists(sprintf("cache_wfs/incendios_%d.geojson", anios_objetivo))]
if (length(faltan) > 0) {
  warning("Faltan anios: ", paste(faltan, collapse = ", "),
          ". Se omitiran del mapa.")
} else {
  cat("\nCache completo. Continuando.\n")
}

# ============================================================
# --- 4. Lectura de incendios desde cache_wfs/ ---
# ============================================================
inc_lista <- lapply(anios_objetivo, function(a) {
  cache <- sprintf("cache_wfs/incendios_%d.geojson", a)
  if (!file.exists(cache)) return(NULL)
  x <- tryCatch(
    read_sf(cache, quiet = TRUE),
    error = function(e) {
      warning("Error leyendo ", a, ": ", conditionMessage(e))
      NULL
    }
  )
  if (!is.null(x) && nrow(x) > 0) {
    x$ANIO_DESC <- a
    message("Leido ", a, ": ", nrow(x), " poligonos")
  }
  x
})

inc_lista_limpia <- lapply(inc_lista, function(x) {
  if (is.null(x)) return(NULL)
  x |> mutate(across(
    where(~ inherits(.x, c("POSIXct", "POSIXt", "Date", "difftime"))),
    ~ as.character(.x)
  ))
})

inc_todos <- bind_rows(Filter(Negate(is.null), inc_lista_limpia))

if (nrow(inc_todos) == 0) {
  stop("No hay datos de incendios en cache_wfs/.")
}

# ============================================================
# --- 5. Recortar al ANP ---
# ============================================================
if (st_crs(inc_todos) != st_crs(malinche)) inc_todos <- st_transform(inc_todos, 4326)

invalidas <- sum(!st_is_valid(inc_todos))
if (invalidas > 0) {
  message("Corrigiendo ", invalidas, " geometrias invalidas")
  inc_todos <- st_make_valid(inc_todos)
}

inc_mal <- st_intersection(inc_todos, malinche)

if (!"AREA_HA"   %in% names(inc_mal)) inc_mal$AREA_HA   <- NA_real_
if (!"MUNICIPIO" %in% names(inc_mal)) inc_mal$MUNICIPIO <- NA_character_
if (!"CLAVEINC"  %in% names(inc_mal)) inc_mal$CLAVEINC  <- NA_character_
if (!"CAUSA"     %in% names(inc_mal)) inc_mal$CAUSA     <- NA_character_

inc_mal <- inc_mal |>
  mutate(AREA_HA = suppressWarnings(as.numeric(AREA_HA)),
         ANIO_DESC = as.integer(ANIO_DESC))

cat("\n=== INCENDIOS RECORTADOS AL ANP ===\n")
print(inc_mal |> st_drop_geometry() |> count(ANIO_DESC, name = "n"))
cat("Total:", nrow(inc_mal), "poligonos\n")

# ============================================================
# --- 6. Sitios de muestreo (KML multicapa o CSV) ---
# ============================================================
sitios_sf <- NULL
archivo_sitios <- NULL

if (file.exists("sitios_y_controles_coordenadas.csv")) {
  archivo_sitios <- "sitios_y_controles_coordenadas.csv"
} else {
  kmls <- list.files(pattern = "\\.kml$", ignore.case = TRUE, recursive = TRUE)
  candidatos <- kmls[!grepl("^salidas/", kmls) &
                       !grepl("centroide|aleatori", kmls, ignore.case = TRUE)]
  if (length(candidatos) == 0) candidatos <- kmls
  con_sitio <- candidatos[grepl("sitio", candidatos, ignore.case = TRUE)]
  if (length(con_sitio) > 0) archivo_sitios <- con_sitio[1]
  else if (length(candidatos) > 0) archivo_sitios <- candidatos[1]
}

if (!is.null(archivo_sitios)) {
  message("Cargando sitios: ", archivo_sitios)
  
  if (grepl("\\.csv$", archivo_sitios, ignore.case = TRUE)) {
    sitios <- read.csv(archivo_sitios, stringsAsFactors = FALSE)
    col_lon  <- grep("^(lon|long|longitud|x)$", names(sitios), ignore.case = TRUE, value = TRUE)[1]
    col_lat  <- grep("^(lat|latitud|y)$", names(sitios), ignore.case = TRUE, value = TRUE)[1]
    col_tipo <- grep("^(tipo|categoria|grupo|clase|rol)$", names(sitios), ignore.case = TRUE, value = TRUE)[1]
    sitios_sf <- st_as_sf(sitios, coords = c(col_lon, col_lat), crs = 4326)
    sitios_sf$popup_txt <- apply(sitios, 1, function(r)
      paste(paste0("<b>", names(r), ":</b> ", r), collapse = "<br>"))
    sitios_sf$.tipo <- if (!is.na(col_tipo)) as.factor(sitios_sf[[col_tipo]]) else "Sitio"
  } else {
    layers <- st_layers(archivo_sitios)$name
    message("   Capas en KML: ", paste(layers, collapse = ", "))
    
    sitios_lista <- lapply(layers, function(l) {
      x <- st_read(archivo_sitios, layer = l, quiet = TRUE) |>
        st_transform(4326) |> st_zm(drop = TRUE, what = "ZM")
      x <- x[grepl("POINT", st_geometry_type(x)), ]
      x$.tipo <- dplyr::case_when(
        grepl("control", l, ignore.case = TRUE) ~ "Control",
        grepl("sitio",   l, ignore.case = TRUE) ~ "Sitio",
        TRUE                                    ~ l
      )
      x
    })
    
    sitios_sf <- dplyr::bind_rows(sitios_lista)
    message("   Total: ", nrow(sitios_sf), " puntos")
    
    col_nombre <- intersect(c("Name", "name", "NAME", "Nombre"), names(sitios_sf))[1]
    if (!is.na(col_nombre)) {
      nm <- as.character(sitios_sf[[col_nombre]])
      anio <- suppressWarnings(as.integer(sub(".*?(20\\d{2}).*", "\\1", nm)))
      sitios_sf$popup_txt <- ifelse(
        is.na(anio),
        paste0("<b>", nm, "</b><br><i>", sitios_sf$.tipo, "</i>"),
        paste0("<b>", nm, "</b><br><i>", sitios_sf$.tipo, "</i><br>Anio: ", anio)
      )
    } else {
      sitios_sf$popup_txt <- as.character(sitios_sf$.tipo)
    }
  }
  
  pal_sitios <- colorFactor(c("#00bfff", "#8b0000", "#4daf4a", "#984ea3", "#ff7f00"),
                            domain = sitios_sf$.tipo)
  message("   ", nrow(sitios_sf), " sitios. Tipos: ",
          paste(unique(sitios_sf$.tipo), collapse = ", "))
} else {
  warning("No hay CSV ni KML de sitios.")
}

# ============================================================
# --- 7. Construir el mapa ---
# Mapas base: solo Esri (Satélite y Topográfico).
# Satélite se muestra por defecto. Sin OSM, sin minimapa.
# ============================================================
anios   <- sort(unique(inc_mal$ANIO_DESC))
paleta  <- c("#e41a1c", "#ff7f00", "#ffd700", "#4daf4a",
             "#377eb8", "#984ea3", "#a65628", "#f781bf")
colores <- colorFactor(palette = paleta, domain = anios)

mapa <- leaflet() |>
  addProviderTiles(providers$Esri.WorldImagery, group = "Satélite") |>
  addProviderTiles(providers$Esri.WorldTopoMap, group = "Topográfico") |>
  addPolygons(
    data = malinche, color = "darkred", weight = 2,
    fillColor = "red", fillOpacity = 0.15, group = "La Malinche",
    label = "La Malinche",
    popup = "<b>La Malinche</b><br>Area Natural Protegida"
  ) |>
  addPolygons(
    data = bbox_poly, color = "blue", weight = 2, dashArray = "5,5",
    fill = FALSE, group = "Bounding box"
  )

for (a in anios) {
  datos_a <- inc_mal[inc_mal$ANIO_DESC == a, ]
  mapa <- mapa |> addPolygons(
    data = datos_a,
    color = ~colores(ANIO_DESC),
    weight = 1,
    fillColor = ~colores(ANIO_DESC),
    fillOpacity = 0.5,
    group = paste("Incendios", a),
    label = ~paste0("Incendio ", ANIO_DESC, " | ", MUNICIPIO,
                    " | ", round(AREA_HA, 1), " ha"),
    popup = ~paste0(
      "<b>Incendio ", ANIO_DESC, "</b><br>",
      "<b>Clave:</b> ", CLAVEINC, "<br>",
      "<b>Municipio:</b> ", MUNICIPIO, "<br>",
      "<b>Causa:</b> ", CAUSA, "<br>",
      "<b>Superficie:</b> ", round(AREA_HA, 2), " ha"
    )
  )
}

if (!is.null(sitios_sf)) {
  mapa <- mapa |> addCircleMarkers(
    data = sitios_sf, radius = 7, color = "white", weight = 2,
    fillColor = ~pal_sitios(.tipo), fillOpacity = 0.95,
    group = "Sitios de muestreo",
    label = ~as.character(.tipo),
    popup = ~popup_txt
  )
}

overlay_grupos <- c("La Malinche", "Bounding box", paste("Incendios", anios))
if (!is.null(sitios_sf)) overlay_grupos <- c(overlay_grupos, "Sitios de muestreo")

mapa <- mapa |>
  fitBounds(
    lng1 = as.numeric(bb_exp["xmin"]), lat1 = as.numeric(bb_exp["ymin"]),
    lng2 = as.numeric(bb_exp["xmax"]), lat2 = as.numeric(bb_exp["ymax"])
  ) |>
  addLayersControl(
    baseGroups    = c("Satélite", "Topográfico"),
    overlayGroups = overlay_grupos,
    options       = layersControlOptions(collapsed = FALSE)
  ) |>
  addScaleBar(position = "bottomleft")

# ============================================================
# --- 8. Guardar HTML ---
# ============================================================
out_html <- "malinche_incendios_2020_2025.html"
saveWidget(mapa, out_html, selfcontained = TRUE)
message("HTML guardado: ", normalizePath(out_html))