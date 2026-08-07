library(tidyverse)
library(readxl)
library(markdown)
library(leaflet)
library(RColorBrewer)
library(plyr)
library(latticeExtra)
library(vegan)
library(plotly)
library(sp)
library(ggthemes)
library(ggmap)
library(ggalt)
library(colorspace)
library(wesanderson)

# Paleta FantasticFox1 de wesanderson, para que el usuario elija el color de la
# gráfica de Floración y fructificación. Los nombres son los que ve en el selector.
paleta_fox <- setNames(
  as.character(wes_palette("FantasticFox1")),
  c("Ocre", "Amarillo", "Azul", "Naranja", "Rojo")
)

# ---------------------------------------------------------------------------
# Paletas para la gráfica de proporción (waffle).
#
# Las paletas de wesanderson traen solo 4-6 colores, y el waffle puede llegar a ~27
# especies. Interpolar UNA sola paleta hasta 27 deja tonos casi idénticos entre
# especies vecinas, así que en vez de eso **cada opción encadena varias paletas**
# para juntar suficientes matices realmente distintos.
# ---------------------------------------------------------------------------
combos_waffle <- list(
  "Vívida"          = c("Zissou1", "Darjeeling1", "FantasticFox1", "Royal1", "Chevalier1"),
  "Tierra y verdes" = c("Cavalcanti1", "Moonrise2", "Royal2", "IsleofDogs2", "Chevalier1"),
  "Cálida"          = c("GrandBudapest1", "Rushmore1", "BottleRocket2", "GrandBudapest2", "Moonrise1"),
  "Variada"         = c("AsteroidCity1", "AsteroidCity2", "FrenchDispatch", "IsleofDogs1", "Darjeeling2")
)

# Junta las paletas de un combo y quita colores repetidos
paleta_combinada <- function(nombre_combo) {
  unique(unlist(lapply(combos_waffle[[nombre_combo]],
                       function(p) as.character(wes_palettes[[p]])),
                use.names = FALSE))
}

# Devuelve n colores del combo elegido. Si alcanzan, se toman tal cual (así quedan
# bien diferenciados); si se piden más de los que hay, se interpola para completar.
colores_waffle <- function(nombre_combo, n) {
  base <- paleta_combinada(nombre_combo)
  if (n <= length(base)) base[seq_len(n)] else colorRampPalette(base)(n)
}

nombres_combos <- names(combos_waffle)

# ---------------------------------------------------------------------------
# Altitud de las capitales de los 32 estados (metros sobre el nivel del mar).
# Sirven como línea de referencia en la gráfica de Altitud: la gente ubica su
# ciudad y ve de inmediato qué frijoles crecen a esa altura.
#
# ⚠️ REVISAR: estos valores son APROXIMADOS y están puestos como punto de
# partida. Antes de publicar conviene verificarlos contra una fuente
# autoritativa (INEGI). Es la única tabla que hay que tocar para corregirlos.
# ---------------------------------------------------------------------------
capitales_altitud <- data.frame(
  ciudad = c(
    "Aguascalientes", "Mexicali", "La Paz", "Campeche", "Tuxtla Gutiérrez",
    "Chihuahua", "Ciudad de México", "Saltillo", "Colima", "Durango",
    "Guanajuato", "Chilpancingo", "Pachuca", "Guadalajara", "Toluca",
    "Morelia", "Cuernavaca", "Tepic", "Monterrey", "Oaxaca de Juárez",
    "Puebla", "Querétaro", "Chetumal", "San Luis Potosí", "Culiacán",
    "Hermosillo", "Villahermosa", "Ciudad Victoria", "Tlaxcala", "Xalapa",
    "Mérida", "Zacatecas"
  ),
  altitud = c(
    1880,   3,   27,   10,  522,
    1415, 2350, 1600,  494, 1890,
    2000, 1360, 2400, 1566, 2660,
    1920, 1510,  915,  540, 1555,
    2135, 1820,   10, 1860,   54,
     210,   10,  321, 2240, 1427,
      10, 2440
  ),
  stringsAsFactors = FALSE
)
# Se ordenan de menor a mayor altitud para que el selector sea más útil
capitales_altitud <- capitales_altitud[order(capitales_altitud$altitud), ]
capitales_opciones <- setNames(
  capitales_altitud$ciudad,
  paste0(capitales_altitud$ciudad, " (", capitales_altitud$altitud, " m)")
)

# NOTA sobre la tipografía de las gráficas:
# El CSS de www/styles.css aplica a toda la interfaz HTML, pero NO a las gráficas,
# porque esas son imágenes que genera R. Se intentó pasarle "PT Sans" a ggplot con
# theme_minimal(base_family = "PT Sans") y **desaparece todo el texto de la gráfica**
# (etiquetas y marcas de los ejes incluidas) en el contexto de esta app, aunque la
# fuente sí esté instalada y funcione en pruebas aisladas. Además tampoco existiría
# en la imagen Docker del servidor. Por eso las gráficas se dejan con la tipografía
# por defecto de ggplot, que renderiza de forma confiable en cualquier entorno.

# En el Excel, parte de la columna Altitud está guardada con formato TEXTO en vez de
# número (de la fila ~4537 en adelante). Eso hacía que readxl soltara más de mil avisos
# "Coercing text to numeric" al arrancar la app. Los datos quedaban bien (verificado:
# 0 valores no numéricos), pero el ruido tapaba cualquier aviso que sí importara.
#
# Ojo: pedir col_types = "numeric" NO los silencia, readxl avisa igual. La forma limpia
# es leer esa columna como TEXTO y convertirla aquí con as.numeric(). Si algún día
# alguien captura un valor no numérico, saldrá un único aviso claro
# ("NAs introduced by coercion") en vez de perderse entre miles.
ARCHIVO_PHASEOLUS <- "data/PhaseolusEne2026_JE014_Unida.xlsx"
HOJA_PHASEOLUS    <- "@PhaseolusEne2026"

tipos_phaseolus <- {
  encabezados <- names(read_xlsx(ARCHIVO_PHASEOLUS, sheet = HOJA_PHASEOLUS, n_max = 0))
  t <- rep("guess", length(encabezados))       # el resto se sigue adivinando
  t[encabezados == "Altitud"] <- "text"
  t
}

Mex <- read_xlsx(ARCHIVO_PHASEOLUS, sheet = HOJA_PHASEOLUS,
                 col_names = TRUE, col_types = tipos_phaseolus)
Mex <- as.data.frame(Mex)
Mex$Altitud <- as.numeric(Mex$Altitud)

Mex2 <- Mex %>% 
  rename("Longitud" = "Long_dec",
         "Latitud" = "Lat_dec",
         "Habitat.1" = "Condición") %>% 
  mutate(RatingCol = as.factor(Especie))
levels(Mex2$RatingCol) <- rainbow_hcl(nlevels(Mex2$RatingCol),
                                      c = 70,
                                      l = 50)

Mex3 <- Mex2 %>%
  dplyr::mutate(Estado = revalue(Estado,c("YUCATÁN" = "Yucatán"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("QUINTANA ROO" = "Quintana Roo"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("TAMAULIPAS" = "Tamaulipas"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("TLAXCALA" = "Tlaxcala"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("JALISCO" = "Jalisco"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("HIDALGO" = "Hidalgo"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("GUERRERO" = "Guerrero"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("SONORA" = "Sonora"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("BAJA CALIFORNIA SUR" = "Baja California Sur"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("GUANAJUATO" = "Guanajuato"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("PUEBLA" = "Puebla"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("OAXACA" = "Oaxaca"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("CHIAPAS" = "Chiapas"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("DURANGO" = "Durango"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("TABASCO" = "Tabasco"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("ZACATECAS" = "Zacatecas"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("NUEVO LEÓN" = "Nuevo León"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("NAYARIT" = "Nayarit"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("AGUASCALIENTES" = "Aguascalientes"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("CHIHUAHUA" = "Chihuahua"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("VERACRUZ DE IGNACIO DE LA LLAVE" = "Veracruz"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("CAMPECHE" = "Campeche"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("SINALOA" = "Sinaloa"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("MICHOACÁN DE OCAMPO" = "Michoacán"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("MÉXICO" = "México"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("DISTRITO FEDERAL" = "Ciudad de México"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("MORELOS" = "Morelos"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("QUERÉTARO DE ARTEAGA" = "Querétaro"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("COAHUILA DE ZARAGOZA" = "Coahuila"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("COLIMA" = "Colima"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("SAN LUIS POTOSÍ" = "San Luis Potosí"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("BAJA CALIFORNIA" = "Baja California"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("ARIZONA" = "Arizona"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("TEXAS" = "Texas"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("HUEHUETENANGO" = "Huehuetenango"))) %>%
  dplyr::mutate(Estado = revalue(Estado,c("NEW MEXICO" = "New Mexico"))) %>%
  dplyr::filter(Habitat.1 != "ND") %>%
  dplyr::filter(Habitat.1 != "Híbrido") %>%
  # Huehuetenango (Guatemala) se excluye de todo el análisis, incluido el mapa
  dplyr::filter(Estado != "Huehuetenango") %>%
  mutate(Altitud = replace(Altitud, Altitud == 9999, NA))

Mex3$AnioColecta <- as.factor(Mex3$AnioColecta)
Mex3$Estado <- as.factor(Mex3$Estado)
Mex3$Habitat.1 <- as.factor(Mex3$Habitat.1)
Mex3$Especie <- as.factor(Mex3$Especie)
Mex3$RatingCol <- as.factor(Mex3$RatingCol)




# Se excluyen también las localidades de EUA (Huehuetenango ya salió en Mex3)
Mex4 <- Mex3 %>%
  filter(Estado != "Arizona") %>%
  filter(Estado != "Texas") %>%
  filter(Estado != "New Mexico")

Mex4$Estado <- factor(Mex4$Estado)
  

# Nota: los rangos altitudinales por especie (antes precalculados aquí como
# Mex5/Mex7/Mex8/Mex9) ahora se calculan en server.R dentro del reactivo Mex10(),
# porque dependen de los estados que elija el usuario.

FloFru <- read_xlsx("data/Flor_fruc.xlsx", sheet = "Rdata", col_names = T)

FloFru$Epoca <- as.factor(FloFru$Epoca)
FloFru$Tipo <- as.factor(FloFru$Tipo)

# Convierte un archivo .md a HTML y fuerza que todas las ligas abran en pestaña nueva
includeMarkdownNewTab <- function(path) {
  html <- markdown::markdownToHTML(path, fragment.only = TRUE)
  html <- gsub("<a href=", '<a target="_blank" rel="noopener noreferrer" href=', html, fixed = TRUE)
  shiny::HTML(html)
}

