library(tidyverse)   # dplyr, tidyr, ggplot2, purrr, stringr, readr
library(rio)         # import()
library(ordinal)   


#library(rstatix)     # pruebas estadísticas ordenadas
#library(scales)      # porcentajes en gráficos

########################   Preparacion de la informacion  ###########


# Parser numérico robusto: tolera coma decimal, espacios,
# celdas "<NA>"/"NA"/vacías, y basura no numérica.
parse_num <- function(x) {
  x <- as.character(x)
  x <- stringr::str_trim(x)
  x[x %in% c("", "<NA>", "NA", "N/A", "na", "NULL")] <- NA_character_
  x <- stringr::str_replace_all(x, ",", ".")
  x <- stringr::str_replace_all(x, "[^0-9.\\-]", "")
  suppressWarnings(as.numeric(x))
}


# Importante: el CSV NO tiene encabezado único.
# La primera fila es un rótulo de sección ("Sitio-...").
# Por eso col_names = FALSE.

DatInc <- rio::import("DatosEMCM.csv", col_names = FALSE)


# head(DatInc, 20)
DatInc_tidy <- DatInc %>%
  
  #Todo a character para evitar conflictos de tipo
  dplyr::mutate(dplyr::across(dplyr::everything(), base::as.character)) %>%
  
  # Detectar rótulos de sección (Sitio-... / Control-...)
  #     grepl() es R base
  dplyr::mutate(
    Section = dplyr::if_else(
      base::grepl("^(Sitio|Control)", V1),
      V1,
      NA_character_
    )
  ) %>%
  
  #El rótulo hacia abajo
  ##Se refiere a cómo tidyr::fill() copia el último valor no-NA hacia las filas
  #siguientes hasta encontrar otro valor
  tidyr::fill(Section, .direction = "down") %>%
  
  # Crear Ind_num para distinguir filas de datos reales.
  # Los rótulos y encabezados NUNCA tienen Ind_num entero.
  dplyr::mutate(Ind_num = parse_num(V1)) %>%
  
  # Quedarnos SOLO con filas donde Ind_num es un entero válido.
  # Esto elimina automáticamente:
  # - filas de rótulo ("Sitio-...", "Control-...")
  # - filas de encabezado ("Ind", "Especie", ...)
  # - filas vacías
  dplyr::filter(!base::is.na(Ind_num), Ind_num == base::round(Ind_num)) %>%
  
  #Renombrar y convertir columnas
  dplyr::transmute(
    Section,
    Ind             = base::as.integer(Ind_num),
    Especie         = V2,
    DAP_cm          = parse_num(V3),
    Altura_m        = parse_num(V4),
    Altura_llama_cm = parse_num(V5),   # NA en Control es correcto
    Severidad       = parse_num(V6)
  ) %>%
  
  # Separar Section en Tipo / Year / Bloque / SitioID
  # strsplit() es R base y maneja "Sitio-25-29-0013"
  # y también "Sitio- 25-29-0032" (con espacio).
  ## strsplit corta cada elemento del vector x por el patrón split
  #Entonces "-\\s*" significa: "un guion seguido de cero o más espacios"
  #recorre cada elemento de la lista, extrae el elemento en la posición n,
  # y garantiza que el resultado sea un vector de caracteres 
  
  dplyr::mutate(parts = base::strsplit(Section, "-\\s*")) %>%
  dplyr::mutate(
    Tipo    = purrr::map_chr(parts, 1),
    Year    = purrr::map_chr(parts, 2),
    Bloque  = purrr::map_chr(parts, 3),
    SitioID = purrr::map_chr(parts, 4)
  ) %>%
  dplyr::select(-parts, -Section) %>%
  
  # Conversion de columnas por "Sitio" a "Incendiado" 
  dplyr::mutate(
    # "Sitio" -> "Incendiado"; Control queda igual
    Tipo = dplyr::recode(Tipo, "Sitio" = "Incendiado"),
    Tipo = base::factor(Tipo, levels = c("Control", "Incendiado")),  # Control = referencia
    
    # Años cortos -> años completos
    #El indentificador contiene el año explicitamente asi que se extrae de ese
    #vector de caracter y se convierte en numerico entero:)
    Year = base::as.integer(Year),
    Year = dplyr::case_when(
      Year == 25 ~ 2025L,
      Year == 20 ~ 2020L,
      TRUE       ~ Year
    ),
    
    Bloque  = base::as.integer(Bloque),
    SitioID = base::as.character(SitioID)   # conserva ceros a la izquierda
  )
DatInc_tidy <- DatInc_tidy %>%
  dplyr::select(-Bloque)

#head(DatInc_tidy, 20)
############################## Analisis de la informacion ###############
############# Comparación entre Incendios y controles en la incidencia ######

#Binarizar la condicion de enfermo
#Posteriormente las categorias binarias pueden ser leidas como caracter


DatInc_tidy <- DatInc_tidy %>%
  dplyr::mutate(
    Enfermo = dplyr::if_else(Severidad > 0, "Sí", "No"),
    Enfermo = base::factor(Enfermo, levels = c("No", "Sí"))
  )
######## Categorias numericas ####
DatInc_tidy <- DatInc_tidy %>%
  dplyr::mutate(
    Enfermo01 = base::as.integer(Severidad > 0)   # 0 = sano, 1 = enfermo
  )

##### Tabla de contingencia ###

tabla <- base::table(DatInc_tidy$Tipo, DatInc_tidy$Enfermo01)
tabla

# Proporciones por grupo
base::prop.table(tabla, margin = 1)
# Totales marginales
stats::addmargins(tabla)

# Chi-cuadrado (con Yates)
#La corrección de continuidad de Yates o prueba de chi-cuadrada de Yates es un 
#ajuste estadístico que se resta 0.5 a la diferencia absoluta entre los valores 
#observados y esperados en tablas de contingencia de 2 × 2 

stats::chisq.test(tabla)

# Chi-cuadrado sin Yates
######## Este es le valor correcto

stats::chisq.test(tabla, correct = FALSE)
# Frecuencias esperadas

stats::chisq.test(tabla)$expected

## Los residuos estandarizados??
stats::chisq.test(tabla, correct = FALSE)$stdres

# Fisher exacto
stats::fisher.test(tabla)



################ Tabla de contingencia #############
# ============================================================
#HEATMAP 2×2
df_chi <- DatInc_tidy %>%
  dplyr::count(Tipo, Enfermo01) %>%
  dplyr::mutate(
    Estado = base::factor(Enfermo01,
                          levels = c(0, 1),
                          labels = c("Sano", "Enfermo"))
  )

chisq <- stats::chisq.test(tabla, correct = FALSE)

label_chi <- sprintf("χ² = %.2f, p = %.3f",
                     chisq$statistic, chisq$p.value)
p_heat <- ggplot2::ggplot(df_chi,
                          ggplot2::aes(x = Tipo, y = Estado, fill = n)) +
  ggplot2::geom_tile(color = "white", linewidth = 1.2) +
  ggplot2::geom_text(
    ggplot2::aes(label = n),
    color = "white", fontface = "bold", size = 7
  ) +
  ggplot2::scale_fill_gradient(
    low  = "#c9d8e8",
    high = "#1f4e79",
    name = "N° árboles"
  ) +
  ggplot2::labs(
    x        = NULL,
    y        = NULL,
    title    = "Tabla de contingencia",
    subtitle = label_chi
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    plot.title         = ggplot2::element_text(hjust = 0.5, face = "bold"),
    plot.subtitle      = ggplot2::element_text(hjust = 0.5),
    panel.grid         = ggplot2::element_blank(),
    axis.text          = ggplot2::element_text(size = 12, face = "bold"),
    legend.position    = "right"
  )

print(p_heat)




# ============================================================
# MANN-WHITNEY SOBRE CONTEO DE ENFERMOS POR SITIO
# + Gráfico de barras con desviación estándar
# ============================================================

# ------------------------------------------------------------
# 1. Conteo de enfermos por sitio
# ------------------------------------------------------------
sitio_conteo <- DatInc_tidy %>%
  dplyr::group_by(Year, SitioID, Tipo) %>%
  dplyr::summarise(
    n        = dplyr::n(),
    enfermos = base::sum(Enfermo01),   # conteo absoluto
    .groups  = "drop"
  )

sitio_conteo

# ------------------------------------------------------------
# Mann-Whitney unilateral por año (sobre conteos)
# ------------------------------------------------------------
conteo_2020 <- sitio_conteo %>% dplyr::filter(Year == "2020")
conteo_2025 <- sitio_conteo %>% dplyr::filter(Year == "2025")

mw_2020 <- stats::wilcox.test(
  x           = conteo_2020$enfermos[conteo_2020$Tipo == "Incendiado"],
  y           = conteo_2020$enfermos[conteo_2020$Tipo == "Control"],
  alternative = "greater",
  exact       = TRUE
)

mw_2025 <- stats::wilcox.test(
  x           = conteo_2025$enfermos[conteo_2025$Tipo == "Incendiado"],
  y           = conteo_2025$enfermos[conteo_2025$Tipo == "Control"],
  alternative = "greater",
  exact       = TRUE
)

mw_2020
mw_2025

# Tabla resumen
resumen_mw <- tibble::tibble(
  Year         = c("2020", "2025"),
  n_Control    = c(base::sum(conteo_2020$Tipo == "Control"),
                   base::sum(conteo_2025$Tipo == "Control")),
  n_Incendiado = c(base::sum(conteo_2020$Tipo == "Incendiado"),
                   base::sum(conteo_2025$Tipo == "Incendiado")),
  W            = c(base::unname(mw_2020$statistic),
                   base::unname(mw_2025$statistic)),
  p_unilateral = c(mw_2020$p.value, mw_2025$p.value)
)

resumen_mw

# ------------------------------------------------------------
#  Resumen: media ± DE del conteo por grupo
# ------------------------------------------------------------
resumen_de <- sitio_conteo %>%
  dplyr::group_by(Year, Tipo) %>%
  dplyr::summarise(
    media = base::mean(enfermos, na.rm = TRUE),
    sd    = stats::sd(enfermos,   na.rm = TRUE),
    n     = dplyr::n(),
    .groups = "drop"
  )

resumen_de

# ------------------------------------------------------------
# Etiquetas de p-valor por panel (W con 1 decimal, p con 2)
# ------------------------------------------------------------
y_top <- base::max(resumen_de$media + resumen_de$sd) * 1.15

etiquetas <- data.frame(
  Year  = c("2020", "2025"),
  x     = 1.5,
  y     = y_top * 0.95,
  label = c(
    sprintf("W = %.1f, p = %.2f",
            base::unname(mw_2020$statistic), mw_2020$p.value),
    sprintf("W = %.1f, p = %.2f",
            base::unname(mw_2025$statistic), mw_2025$p.value)
  )
)

etiquetas

# ------------------------------------------------------------
# Gráfico: barras + desviación estándar
# ------------------------------------------------------------
p_bar <- ggplot2::ggplot(resumen_de,
                         ggplot2::aes(x = Tipo, y = media, fill = Tipo)) +
  ggplot2::geom_col(width = 0.55, alpha = 0.75,
                    color = "black", linewidth = 0.3) +
  ggplot2::geom_errorbar(
    ggplot2::aes(ymin = media - sd, ymax = media + sd),
    width = 0.18, linewidth = 0.8, color = "black"
  ) +
  ggplot2::geom_jitter(
    data = sitio_conteo,
    ggplot2::aes(x = Tipo, y = enfermos),
    width = 0.12, height = 0, size = 2.5,
    alpha = 0.9, color = "black",
    inherit.aes = FALSE
  ) +
  ggplot2::geom_text(
    data = etiquetas,
    ggplot2::aes(x = x, y = y, label = label),
    inherit.aes = FALSE,
    size = 3.8, hjust = 0.5
  ) +
  ggplot2::facet_wrap(~ Year) +
  ggplot2::scale_y_continuous(
    limits = c(0, y_top),
    breaks = seq(0, 20, by = 2),
    expand = c(0.02, 0)
  ) +
  ggplot2::scale_fill_manual(
    values = c("Control" = "#2c7bb6", "Incendiado" = "#d7191c")
  ) +
  ggplot2::labs(
    x        = NULL,
    y        = "Número de árboles enfermos por sitio",
    title    = "Conteo de árboles enfermos por tratamiento y año",
    #  subtitle = expression(H[1]*": Incendiado > Control (U de Mann-Whitney unilateral)"),
    # caption  = "Barras = media ± desviación estándar; puntos = sitios individuales (n = 3 por grupo)"
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    legend.position = "none",
    plot.title      = ggplot2::element_text(hjust = 0.5, face = "bold"),
    plot.subtitle   = ggplot2::element_text(hjust = 0.5),
    plot.caption    = ggplot2::element_text(hjust = 0.5, size = 9)
  )

base::print(p_bar)
######## spearman ####### 

# CORRELACIÓN DE SPEARMAN + RECTA DE REGRESIÓN

spearman <- stats::cor.test(
  DatInc_tidy$DAP_cm,
  DatInc_tidy$Severidad,
  method = "spearman",
  use    = "complete.obs"
)

spearman

rho     <- base::unname(spearman$estimate)
p_value <- spearman$p.value
n_obs   <- base::nrow(DatInc_tidy)

base::cat(sprintf("\nSpearman rho = %.3f\np = %.4f\nn = %d\n",
                  rho, p_value, n_obs))

# ------------------------------------------------------------
# Plot con recta de regresión
# ------------------------------------------------------------
p_cor <- ggplot2::ggplot(DatInc_tidy,
                         ggplot2::aes(x = DAP_cm, y = Severidad)) +
  ggplot2::geom_jitter(width = 0.4, height = 0.15,
                       alpha = 0.45, size = 1.8,
                       color = "#2c3e50") +
  ggplot2::geom_smooth(method = "lm", se = TRUE,
                       color = "#c0392b", fill = "#c0392b",
                       alpha = 0.15, linewidth = 1.1) +
  ggplot2::scale_x_continuous(
    limits = c(0, 105),
    breaks = seq(0, 100, by = 20),
    expand = c(0.02, 0)
  ) +
  ggplot2::scale_y_continuous(
    limits = c(-0.3, 5.3),
    breaks = 0:5,
    expand = c(0.02, 0)
  ) +
  ggplot2::annotate(
    "text", x = 100, y = 5,
    label = sprintf("Spearman: rho == %.2f", rho),
    parse = TRUE, hjust = 1, size = 4
  ) +
  ggplot2::annotate(
    "text", x = 100, y = 4.6,
    label = sprintf("italic(p) == %.3f", p_value),
    parse = TRUE, hjust = 1, size = 4
  ) +
  ggplot2::labs(
    x        = "DAP (cm)",
    y        = "Severidad (0–5)",
    title    = "Correlación de Spearman: DAP y severidad",
    #subtitle = "Línea roja = regresión lineal; banda = IC 95 %"
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    plot.title    = ggplot2::element_text(hjust = 0.5, face = "bold"),
    plot.subtitle = ggplot2::element_text(hjust = 0.5)
  )

print(p_cor)
# CORRELACIÓN DE SPEARMAN: DAP vs SEVERIDAD
# SOLO SITIOS INCENDIADOS

# Filtrar solo incendiados

DatInc_quemado <- DatInc_tidy %>%
  dplyr::filter(Tipo == "Incendiado")

# ------------------------------------------------------------
# Test de Spearman sobre incendiados
# ------------------------------------------------------------
spearman_q <- stats::cor.test(
  DatInc_quemado$DAP_cm,
  DatInc_quemado$Severidad,
  method = "spearman",
  use    = "complete.obs"
)

spearman_q

rho_q   <- base::unname(spearman_q$estimate)
p_q     <- spearman_q$p.value
n_q     <- base::nrow(DatInc_quemado)

#base::cat(sprintf("\nSpearman (Incendiado) rho = %.3f\np = %.4f\nn = %d\n",
 #                 rho_q, p_q, n_q))






#############################################################
# CORRELACIÓN DE SPEARMAN: DAP vs SEVERIDAD
# SOLO SITIOS INCENDIADOS

# ------------------------------------------------------------
#  Función para formatear el p-valor
# ------------------------------------------------------------
formato_p <- function(p) {
  if (p < 0.001) {
    base::format(p, scientific = TRUE, digits = 3)
  } else {
    base::sprintf("%.3f", p)
  }
}

# ------------------------------------------------------------
# Filtrar solo incendiados
# ------------------------------------------------------------
DatInc_quemado <- DatInc_tidy %>%
  dplyr::filter(Tipo == "Incendiado")

# ------------------------------------------------------------
# Test de Spearman sobre incendiados
# ------------------------------------------------------------
spearman_q <- stats::cor.test(
  DatInc_quemado$DAP_cm,
  DatInc_quemado$Severidad,
  method = "spearman",
  use    = "complete.obs"
)

spearman_q

rho_q <- base::unname(spearman_q$estimate)
p_q   <- spearman_q$p.value
n_q   <- base::nrow(DatInc_quemado)

base::cat(sprintf("\nSpearman (Incendiado) rho = %.3f\np = %s\nn = %d\n",
                  rho_q, formato_p(p_q), n_q))

# ------------------------------------------------------------
# Etiquetas formateadas
# ------------------------------------------------------------
label_rho <- sprintf("Spearman: rho == %.2f", rho_q)
label_p   <- sprintf("italic(p) == %s", formato_p(p_q))

# ------------------------------------------------------------
# Plot solo incendiados
# ------------------------------------------------------------

max_dap_q <- max(DatInc_quemado$DAP_cm, na.rm = TRUE)

label_spearman <- sprintf("Spearman: rho = %.2f\np = %s",
                          rho_q, formato_p(p_q))


p_cor_q <- ggplot2::ggplot(DatInc_quemado,
                           ggplot2::aes(x = DAP_cm, y = Severidad)) +
  ggplot2::geom_jitter(width = 0.4, height = 0.15,
                       alpha = 0.55, size = 1.9,
                       color = "#7a1f1f") +
  ggplot2::geom_smooth(method = "lm", se = TRUE,
                       color = "#c0392b", fill = "#c0392b",
                       alpha = 0.15, linewidth = 1.1) +
  ggplot2::scale_x_continuous(
    limits = c(0, max_dap_q),
    breaks = seq(0, 80, by = 20),
    expand = c(0.02, 0)
  ) +
  ggplot2::scale_y_continuous(
    limits = c(-1.5, 6.5),
    breaks = 0:5,
    expand = c(0.02, 0)
  ) +
  ggplot2::annotate(
    "label",
    x         = max_dap_q * 0.99,
    y         = 6.3,
    label     = label_spearman,
    hjust     = 1, vjust = 1,
    size      = 3.6,
    linewidth = 0.2,
    fill      = "white",
    alpha     = 0.9
  ) +
  ggplot2::labs(
    x        = "DAP (cm)",
    y        = "Severidad (0–5)",
    title    = "Correlación de Spearman: DAP y severidad"
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(hjust = 0.5, face = "bold")
  )

print(p_cor_q)


# ------------------------------------------------------------
# 0. Variable respuesta binaria + Year como factor
# ------------------------------------------------------------
DatInc_tidy <- DatInc_tidy %>%
  dplyr::mutate(
    Enfermo = base::as.integer(Severidad > 0),
    Year    = base::factor(Year, levels = c(2020, 2025))
  )

# ------------------------------------------------------------
# 1. Modelo logístico
# ------------------------------------------------------------
m_final <- stats::glm(
  Enfermo ~ Tipo + Year + DAP_cm,
  family = stats::binomial,
  data   = DatInc_tidy
)

base::summary(m_final)

# ------------------------------------------------------------
# 2. Odds ratios con IC 95 %
# ------------------------------------------------------------
OR_tabla <- base::cbind(
  OR    = base::exp(stats::coef(m_final)),
  IC_lo = base::exp(stats::confint.default(m_final)[, 1]),
  IC_hi = base::exp(stats::confint.default(m_final)[, 2]),
  p     = base::summary(m_final)$coefficients[, "Pr(>|z|)"]
)
base::round(OR_tabla, 3)

# ------------------------------------------------------------
# 3. Etiqueta de la fórmula
# ------------------------------------------------------------
label_txt <- "Enfermo ~ Tipo + Year + DAP (cm)"

# ------------------------------------------------------------
# 4. Predicciones para las 4 curvas (Tipo × Year)
#    Los niveles de Year deben coincidir con los del modelo
# ------------------------------------------------------------
niveles_year <- base::levels(DatInc_tidy$Year)

nueva_full <- base::expand.grid(
  Tipo   = base::factor(c("Control", "Incendiado"),
                        levels = c("Control", "Incendiado")),
  Year   = base::factor(niveles_year, levels = niveles_year),
  DAP_cm = base::seq(2, 100, length.out = 100)
)

pred_full <- stats::predict(m_final, nueva_full,
                            type = "link", se.fit = TRUE)

nueva_full$fit   <- stats::plogis(pred_full$fit)
nueva_full$IC_lo <- stats::plogis(pred_full$fit - 1.96 * pred_full$se.fit)
nueva_full$IC_hi <- stats::plogis(pred_full$fit + 1.96 * pred_full$se.fit)

# ------------------------------------------------------------
# 5. Predicciones en el DAP promedio
# ------------------------------------------------------------
DAP_mean <- base::mean(DatInc_tidy$DAP_cm, na.rm = TRUE)

nueva_mean <- base::expand.grid(
  Tipo   = base::factor(c("Control", "Incendiado"),
                        levels = c("Control", "Incendiado")),
  Year   = base::factor(niveles_year, levels = niveles_year),
  DAP_cm = DAP_mean
)

pred_mean <- stats::predict(m_final, nueva_mean,
                            type = "link", se.fit = TRUE)

nueva_mean$fit   <- stats::plogis(pred_mean$fit)
nueva_mean$IC_lo <- stats::plogis(pred_mean$fit - 1.96 * pred_mean$se.fit)
nueva_mean$IC_hi <- stats::plogis(pred_mean$fit + 1.96 * pred_mean$se.fit)

# ------------------------------------------------------------
# 6. Gráfico combinado
# ------------------------------------------------------------
p_combo <- ggplot2::ggplot() +
  ggplot2::geom_ribbon(
    data = nueva_full,
    ggplot2::aes(x = DAP_cm, ymin = IC_lo, ymax = IC_hi,
                 fill = Tipo, group = interaction(Tipo, Year)),
    alpha = 0.10, color = NA
  ) +
  ggplot2::geom_line(
    data = nueva_full,
    ggplot2::aes(x = DAP_cm, y = fit,
                 color    = Tipo,
                 linetype = Year,
                 group    = interaction(Tipo, Year)),
    linewidth = 1.1
  ) +
  ggplot2::geom_errorbar(
    data = nueva_mean,
    ggplot2::aes(x = DAP_cm, ymin = IC_lo, ymax = IC_hi,
                 color = Tipo),
    width = 2, linewidth = 0.7
  ) +
  ggplot2::geom_point(
    data = nueva_mean,
    ggplot2::aes(x = DAP_cm, y = fit,
                 color = Tipo, shape = Year),
    size = 4, fill = "white", stroke = 1.2
  ) +
  ggplot2::annotate(
    "text",
    x        = 5, y = 1.02,
    label    = label_txt,
    hjust    = 0, vjust = 1,
    size     = 4,
    fontface = "italic"
  ) +
  ggplot2::scale_color_manual(
    values = c("Control"    = "#1f4e79",
               "Incendiado" = "#e63946")
  ) +
  ggplot2::scale_fill_manual(
    values = c("Control"    = "#1f4e79",
               "Incendiado" = "#e63946")
  ) +
  ggplot2::scale_linetype_manual(
    values = c("2020" = "solid",
               "2025" = "dashed")
  ) +
  ggplot2::scale_shape_manual(
    values = c("2020" = 21,
               "2025" = 24)
  ) +
  ggplot2::scale_y_continuous(
    labels = scales::percent,
    limits = c(0, 1.08),
    breaks = seq(0, 1, by = 0.25),
    expand = c(0.02, 0)
  ) +
  ggplot2::scale_x_continuous(
    limits = c(0, 105),
    breaks = seq(0, 100, by = 20),
    expand = c(0.02, 0)
  ) +
  ggplot2::labs(
    x        = "DAP (cm)",
    y        = "Probabilidad predicha de enfermo",
    color    = "Tratamiento",
    fill     = "Tratamiento",
    linetype = "Año",
    shape    = "Año",
    title    = "Probabilidad de enfermar según tratamiento, año y DAP"
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    plot.title      = ggplot2::element_text(hjust = 0.5, face = "bold"),
    plot.margin     = ggplot2::margin(10, 5, 10, 5),
    
    legend.position      = "right",
    legend.title         = ggplot2::element_text(size = 9, face = "bold"),
    legend.text          = ggplot2::element_text(size = 8),
    legend.key.size      = grid::unit(0.5, "cm"),
    legend.key.spacing.y = grid::unit(0.15, "cm"),
    legend.spacing.y     = grid::unit(0.4,  "cm"),
    legend.spacing.x     = grid::unit(0.2,  "cm"),
    
    axis.title      = ggplot2::element_text(size = 11),
    axis.text       = ggplot2::element_text(size = 9)
  )

base::print(p_combo)
