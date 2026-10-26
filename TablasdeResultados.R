library(gridExtra)
library(grid)

# ============================================================
# PREPARACIÓN DE LAS TABLAS
# ============================================================

# --- 1. TABLA CHI-CUADRADA ---
tabla_obs <- as.data.frame.matrix(addmargins(tabla))
tabla_obs$Tipo <- rownames(tabla_obs)
tabla_obs <- tabla_obs[, c("Tipo", "0", "1", "Sum")]
colnames(tabla_obs) <- c("Tratamiento", "Sano (0)", "Enfermo (1)", "Total")
rownames(tabla_obs) <- NULL

# --- 2. TABLA MANN-WHITNEY (Conteo) ---
tabla_mw <- resumen_mw
colnames(tabla_mw) <- c("Año", "n Control", "n Incendiado", "Estadístico W", "p-valor")
tabla_mw$Año <- as.character(tabla_mw$Año) # <-- CORREGIDO AQUÍ

# --- 3. TABLA SPEARMAN ---
tabla_spearman <- data.frame(
  Datos = c("Global (Todos los árboles)", "Solo Incendiados"),
  n = c(n_obs, n_q),
  rho = c(round(rho, 3), round(rho_q, 3)),
  p_valor = c(
    ifelse(p_value < 0.001, "< 0.001", sprintf("%.3f", p_value)),
    ifelse(p_q < 0.001, "< 0.001", sprintf("%.3f", p_q))
  )
)

# --- 4. TABLA REGRESIÓN LOGÍSTICA ---
tabla_logit <- as.data.frame(OR_tabla)
tabla_logit$Coeficiente <- rownames(tabla_logit)
tabla_logit <- tabla_logit[, c("Coeficiente", "OR", "IC_lo", "IC_hi", "p")]
colnames(tabla_logit) <- c("Coeficiente", "Odds Ratio (OR)", "IC 95% Inferior", "IC 95% Superior", "p-valor")
tabla_logit$p <- ifelse(tabla_logit$p < 0.001, "< 0.001", sprintf("%.3f", tabla_logit$p))
tabla_logit[, 2:4] <- round(tabla_logit[, 2:4], 3)
rownames(tabla_logit) <- NULL


# ============================================================
# CREACIÓN DEL PDF
# ============================================================
pdf("Tablas_Resultados_Fitosanitarios.pdf", width = 11, height = 8.5)

# Página 1: Chi-cuadrada
grid.arrange(
  tableGrob(tabla_obs, rows = NULL, 
            theme = ttheme_minimal(base_size = 12)),
  top = textGrob("Tabla 1. Tabla de contingencia: Tratamiento vs Estado fitosanitario\n(Chi-cuadrada sin corrección: χ² = 5.17, gl = 1, p = 0.023)", 
                 gp = gpar(fontsize = 14, fontface = "bold"))
)

# Página 2: Mann-Whitney
grid.arrange(
  tableGrob(tabla_mw, rows = NULL, 
            theme = ttheme_minimal(base_size = 12)),
  top = textGrob("Tabla 2. Prueba U de Mann-Whitney para el conteo de árboles enfermos\n(Comparación Incendiado vs Control por año)", 
                 gp = gpar(fontsize = 14, fontface = "bold"))
)

# Página 3: Spearman
grid.arrange(
  tableGrob(tabla_spearman, rows = NULL, 
            theme = ttheme_minimal(base_size = 12)),
  top = textGrob("Tabla 3. Correlación de Spearman entre DAP y Severidad de la enfermedad\n(Análisis global y restringido a sitios incendiados)", 
                 gp = gpar(fontsize = 14, fontface = "bold"))
)

# Página 4: Regresión Logística
grid.arrange(
  tableGrob(tabla_logit, rows = NULL, 
            theme = ttheme_minimal(base_size = 12)),
  top = textGrob("Tabla 4. Modelo de regresión logística binomial\n(Probabilidad de enfermedad en función del Tratamiento, Año y DAP)", 
                 gp = gpar(fontsize = 14, fontface = "bold"))
)

dev.off()

cat("¡PDF generado con éxito! Revisa tu carpeta de trabajo.")