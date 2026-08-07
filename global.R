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

# "Phaseolus vulgaris" -> "P. vulgaris". Todas las especies de la app son del mismo
# género, así que repetirlo en cada etiqueta solo gasta espacio. El nombre completo se
# conserva en los tooltips.
abreviar_especie <- function(x) sub("^Phaseolus\\s+", "P. ", as.character(x))

# ---------------------------------------------------------------------------
# Altitud de las capitales de los 32 estados (metros sobre el nivel del mar).
# Sirven como línea de referencia en la gráfica de Altitud: la gente ubica su
# ciudad y ve de inmediato qué frijoles crecen a esa altura.
#
# FUENTE: INEGI, Catálogo Único de Claves de Áreas Geoestadísticas
# (archivo AGEEML, julio 2026), columna ALTITUD de la cabecera municipal
# (CVE_LOC = 0001) de cada capital. La columna `cvegeo` guarda la clave exacta
# de la localidad, así que cada número es rastreable hasta su renglón de origen.
#
# Dos precisiones:
#  - La Ciudad de México no existe como localidad única en el catálogo (está
#    partida en 16 alcaldías). Se usa Cuauhtémoc, que es donde está el Zócalo.
#  - `ciudad` y `estado` usan los nombres comunes que emplea la app, no los
#    oficiales de INEGI ("Coahuila", no "Coahuila de Zaragoza"), para que
#    `estado` se pueda unir con la columna Estado de los datos de Phaseolus.
# ---------------------------------------------------------------------------
capitales_altitud <- data.frame(
  ciudad = c(
    "Aguascalientes", "Mexicali",    "La Paz",       "Campeche",
    "Saltillo",       "Colima",      "Tuxtla Gutiérrez", "Chihuahua",
    "Ciudad de México", "Durango",   "Guanajuato",   "Chilpancingo",
    "Pachuca",        "Guadalajara", "Toluca",       "Morelia",
    "Cuernavaca",     "Tepic",       "Monterrey",    "Oaxaca de Juárez",
    "Puebla",         "Querétaro",   "Chetumal",     "San Luis Potosí",
    "Culiacán",       "Hermosillo",  "Villahermosa", "Ciudad Victoria",
    "Tlaxcala",       "Xalapa",      "Mérida",       "Zacatecas"
  ),
  estado = c(
    "Aguascalientes", "Baja California", "Baja California Sur", "Campeche",
    "Coahuila",       "Colima",      "Chiapas",      "Chihuahua",
    "Ciudad de México", "Durango",   "Guanajuato",   "Guerrero",
    "Hidalgo",        "Jalisco",     "México",       "Michoacán",
    "Morelos",        "Nayarit",     "Nuevo León",   "Oaxaca",
    "Puebla",         "Querétaro",   "Quintana Roo", "San Luis Potosí",
    "Sinaloa",        "Sonora",      "Tabasco",      "Tamaulipas",
    "Tlaxcala",       "Veracruz",    "Yucatán",      "Zacatecas"
  ),
  cvegeo = c(
    "010010001", "020020001", "030030001", "040020001",
    "050300001", "060020001", "071010001", "080190001",
    "090150001", "100050001", "110150001", "120290001",
    "130480001", "140390001", "151060001", "160530001",
    "170070001", "180170001", "190390001", "200670001",
    "211140001", "220140001", "230040001", "240280001",
    "250060001", "260300001", "270040001", "280410001",
    "290330001", "300870001", "310500001", "320560001"
  ),
  altitud = c(
    1878,    0,   31,    6, 1600,  484,  522, 1421,
    2230, 1893, 2019, 1255, 2379, 1537, 2671, 1904,
    1523,  926,  536, 1542, 2141, 1831,    2, 1865,
      57,  200,   11,  322, 2228, 1393,   10, 2427
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
  # Las localidades fuera de México se excluyen de TODO el análisis, incluido el mapa
  # y los selectores de estado: Huehuetenango (Guatemala) y las de Estados Unidos.
  # Son 18 registros de 5,720 (Arizona 11, New Mexico 4, Texas 3).
  dplyr::filter(!Estado %in% c("Huehuetenango", "Arizona", "New Mexico", "Texas")) %>%
  mutate(Altitud = replace(Altitud, Altitud == 9999, NA))

Mex3$AnioColecta <- as.factor(Mex3$AnioColecta)
Mex3$Estado <- as.factor(Mex3$Estado)
Mex3$Habitat.1 <- as.factor(Mex3$Habitat.1)
Mex3$Especie <- as.factor(Mex3$Especie)
Mex3$RatingCol <- as.factor(Mex3$RatingCol)


# Antes existía un Mex4 que era Mex3 sin las localidades de EUA. Ahora esas ya salen
# desde Mex3, así que Mex4 era una copia idéntica y se eliminó: Mex3 es la única
# fuente de datos filtrados de la app.


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

