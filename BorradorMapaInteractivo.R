library(terra)
library(sf)


malinche <- sf::read_sf("Poligonanpsmex/PolMalinche/WDPA_WDOECM_Sep2026_Public_212_shp-polygons.shp")

mex_pais <- gadm("MEX", level = 0, path = "c:/Users/31628/Documents/MontañasdelCentro/")


# --- 2. Convertir el SpatVector a sf ---
mex_pais_sf <- st_as_sf(mex_pais)

# --- 3. Verificar que ambos estén en el mismo CRS (4326) ---
malinche    <- st_transform(malinche, 4326)
mex_pais_sf <- st_transform(mex_pais_sf, 4326)


bbbox <- extent(malinche)

# --- 4. Graficar ---
#ggplot() +
 # geom_sf(data = mex_pais_sf,
   #       fill = "grey95", color = "grey40", linewidth = 0.3) +
  #geom_sf(data = malinche,
    #      fill = "red", color = "darkred",
     #     alpha = 0.5, linewidth = 0.7) +
#  theme_void()



bb <- st_bbox(malinche)
m  <- 0.25 * max(as.numeric(bb["xmax"] - bb["xmin"]),
                 as.numeric(bb["ymax"] - bb["ymin"]))

ggplot() +
  geom_sf(data = mex_pais_sf,
          fill = "grey95", color = "grey40", linewidth = 0.3) +
  geom_sf(data = malinche,
          fill = "red", color = "darkred",
          alpha = 0.5, linewidth = 0.7) +
  coord_sf(
    xlim = c(as.numeric(bb["xmin"]) - m, as.numeric(bb["xmax"]) + m),
    ylim = c(as.numeric(bb["ymin"]) - m, as.numeric(bb["ymax"]) + m),
    expand = FALSE,
    crs = st_crs(4326)
  ) +
  theme_void()


################### Mapa interactivo con Leaflet #######################







