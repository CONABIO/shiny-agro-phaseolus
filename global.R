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
# Las cinco especies de frijol domesticadas en el mundo; cuatro se domesticaron en
# México. Se usan para resaltarlas en la gráfica de Altitud.
#
# Ojo con las variedades: en dos casos lo domesticado NO es la especie completa sino
# una variedad. `P. acutifolius var. acutifolius` y `P. lunatus var. lunatus` son las
# cultivadas; `var. tenuifolius` y `var. silvester` son sus contrapartes silvestres y
# NO deben resaltarse.
#
# Los registros identificados solo hasta especie ("Phaseolus acutifolius" y
# "Phaseolus lunatus", sin variedad) quedan fuera a propósito: no se sabe si son la
# forma cultivada o la silvestre.
# ---------------------------------------------------------------------------
especies_domesticadas <- c(
  "Phaseolus vulgaris",
  "Phaseolus coccineus",
  "Phaseolus dumosus",
  "Phaseolus acutifolius var. acutifolius",
  "Phaseolus lunatus var. lunatus"
)

# Clasifica especies en los dos grupos que usa el waffle al colorear por condición.
# Es atributo de la ESPECIE, no del registro: no usa la columna Habitat.1
# (Cultivado/Escapado/Silvestre), que describe cómo se colectó cada ejemplar y no
# coincide con esto — P. coccineus es especie domesticada pero 865 de sus registros
# son silvestres. Se eligió el criterio por especie para que el color signifique lo
# mismo aquí que en la gráfica de Altitud.
grupo_domesticacion <- function(x) {
  factor(ifelse(as.character(x) %in% especies_domesticadas,
                "Domesticadas", "Silvestres"),
         levels = c("Domesticadas", "Silvestres"))
}

# Rojo: el mismo con el que Altitud resalta las domesticadas, para que el código de
# color sea consistente entre pestañas. Azul: contraste alto y distinguible también
# para daltonismo rojo-verde, el más común.
colores_condicion <- c("Domesticadas" = "#B40F20", "Silvestres" = "#46ACC8")

# ---------------------------------------------------------------------------
# Gráfica de Floración y fructificación: opción de ver las dos épocas a la vez.
# El valor va en una constante porque lo comparten el selector de ui.R y la lógica
# de server.R, y un typo entre los dos no daría error, solo dejaría de funcionar.
AMBAS_EPOCAS <- "Ambas"

# Orden de las dos épocas. Fija qué triángulo es cuál (floración arriba-izquierda,
# fructificación abajo-derecha) y el orden de la leyenda.
EPOCAS <- c("Floración", "Fructificación")

# Colores de arranque de cada época, como NOMBRES de paleta_fox: el usuario los cambia
# desde los selectores, igual que en la vista de una sola época. Naranja y azul de
# salida porque es cálido contra frío —contrastan entre sí y además se distinguen con
# daltonismo rojo-verde, el más común— y porque dejan fuera el Rojo (#B40F20), que en
# esta app ya significa "especie domesticada" (ver colores_condicion y la gráfica de
# Altitud); reusarlo aquí con otro sentido rompería el código de color.
colores_epoca_default <- c("Floración" = "Naranja", "Fructificación" = "Azul")

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
         "Habitat.1" = "Condición")
# El color de cada punto del mapa ya no se precalcula aquí: ahora se resuelve al
# dibujar, según la paleta que elija el usuario (ver paletas_mapa, más abajo).

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

# Antes existía un Mex4 que era Mex3 sin las localidades de EUA. Ahora esas ya salen
# desde Mex3, así que Mex4 era una copia idéntica y se eliminó: Mex3 es la única
# fuente de datos filtrados de la app.

# ---------------------------------------------------------------------------
# Especies que se ofrecen en la pestaña "Altitud por especie".
#
# Esa gráfica dibuja el gradiente altitudinal de cada especie, así que necesita varios
# valores distintos para que haya algo que mostrar: con uno o dos puntos no se ve un
# gradiente, se ve ruido. Se piden más de 4 altitudes DISTINTAS (no registros crudos:
# cincuenta colectas a 100 m siguen siendo un solo punto en esa figura).
#
# Deja fuera 10 de las 59 especies con dato de altitud; las 49 restantes se ofrecen en
# el selector. Las excluidas siguen apareciendo en el resto de la app.
# ---------------------------------------------------------------------------
MIN_ALTITUDES_GRADIENTE <- 5

# Extremos del deslizador de altitud del mapa. Se calculan de los datos para que el
# control se ajuste solo si estos cambian, y ui.R y server.R los leen de aquí para
# coincidir en qué significa "rango completo".
RANGO_ALTITUD_MAPA <- range(Mex3$Altitud, na.rm = TRUE)

especies_con_gradiente <- local({
  u <- dplyr::distinct(Mex3[!is.na(Mex3$Altitud), ], Especie, Altitud)
  n <- table(droplevels(u$Especie))
  sort(names(n)[n >= MIN_ALTITUDES_GRADIENTE])
})

# ---------------------------------------------------------------------------
# Paletas del mapa de Distribución (selector en la esquina inferior izquierda).
#
# El color del mapa NO pretende que se identifique cada especie: con 60 especies eso
# es imposible de leer y además no hay leyenda. Su función es transmitir de un vistazo
# la DIVERSIDAD; quien quiera el detalle usa los filtros y el popup de cada punto.
#
#  - Paleta 1: la original, un arcoíris HCL. rainbow_hcl mantiene constantes la
#    luminosidad y la saturación, así que ninguna especie destaca artificialmente.
#    Con 60 especies los tonos vecinos quedan a 6° y se ven como un degradado.
#  - Paletas 2 y 3: armadas encadenando 10 paletas de wesanderson cada una y luego
#    (a) quitando los colores a menos de 10 de distancia perceptual entre sí,
#    (b) quitando los casi blancos y casi negros, que sobre el mapa claro de
#        CartoDB.Positron no se verían, y
#    (c) reordenando para que cada color sea el más lejano posible del anterior,
#        de modo que al reciclarse sobre las 60 especies los vecinos contrasten.
#    No comparten ningún color entre ellas.
# ---------------------------------------------------------------------------
paletas_mapa <- list(
  "Paleta 1" = rainbow_hcl(nlevels(Mex3$Especie), c = 70, l = 50),
  "Paleta 2" = c(
    "#3B9AB2", "#F21A00", "#00A08A", "#C93312", "#85D4E3", "#F98400",
    "#046C9A", "#E1AF00", "#5785C1", "#FBA72A", "#35274A", "#DD8D29",
    "#78B7C5", "#B40F20", "#0B775E", "#FD6467", "#3F5151", "#D67236",
    "#899DA4", "#A42820", "#CDC08C", "#5B1A18", "#E1BD6D", "#4E2A1E",
    "#F1BB7B", "#5F5647", "#D69C4E", "#F4B5BD", "#9C964A", "#CB7A5C"
  ),
  "Paleta 3" = c(
    "#9986A5", "#D8B70A", "#273046", "#C52E19", "#54D8B1", "#972D15",
    "#90D4CC", "#AF4E24", "#7FC0C6", "#9A8822", "#39312F", "#CCBA72",
    "#175149", "#F8AFA8", "#02401B", "#B67C3B", "#446455", "#CCC591",
    "#79402E", "#81A88D", "#354823", "#C7B19C", "#798E87", "#AC9765",
    "#8D8680", "#A2A475", "#AA9486"
  )
)

# Devuelve un vector de colores NOMBRADO POR ESPECIE. Que esté nombrado es lo que hace
# que cada especie conserve su color al filtrar: el color se busca por nombre, no por
# posición dentro del subconjunto filtrado.
# Las paletas 2 y 3 tienen menos de 60 colores, así que se RECICLAN (rep_len) en vez de
# interpolarse: interpolar generaría tonos intermedios casi idénticos y se perdería
# justo el contraste que se buscaba.
colores_mapa <- function(nombre) {
  setNames(rep_len(paletas_mapa[[nombre]], nlevels(Mex3$Especie)),
           levels(Mex3$Especie))
}

nombres_paletas_mapa <- names(paletas_mapa)
  

# Nota: los rangos altitudinales por especie (antes precalculados aquí como
# Mex5/Mex7/Mex8/Mex9) ahora se calculan en server.R dentro del reactivo Mex10(),
# porque dependen de los estados que elija el usuario.

FloFru <- read_xlsx("data/Flor_fruc.xlsx", sheet = "Rdata", col_names = T)

# Arreglo del nombre de las dos variedades. En el Excel, sus dos filas traen el
# epíteto de la especie en la columna del GÉNERO ("acutifolius acutifolius" en vez de
# "Phaseolus acutifolius acutifolius"), así que el eje de la gráfica las mostraba sin
# género — y son justo dos de las cinco especies domesticadas.
#
# Se antepone el género en vez de sustituir esa columna: sustituirla daría "Phaseolus
# acutifolius" y se perdería el epíteto de la variedad, que es lo que las distingue de
# su contraparte silvestre (var. tenuifolius y var. silvester).
#
# Queda sin el "var." de la forma taxonómica completa ("Phaseolus lunatus var.
# lunatus") porque ese nombre no cabe en el eje; es decisión del autor de la app.
es_variedad <- FloFru$NombreCategoriaTaxonomica == "variedad"
FloFru$Nombre_1_Nombre[es_variedad] <- paste("Phaseolus",
                                             FloFru$Nombre_1_Nombre[es_variedad])

FloFru$Epoca <- as.factor(FloFru$Epoca)
FloFru$Tipo <- as.factor(FloFru$Tipo)

# Convierte un archivo .md a HTML y fuerza que todas las ligas abran en pestaña nueva
includeMarkdownNewTab <- function(path) {
  html <- markdown::markdownToHTML(path, fragment.only = TRUE)
  html <- gsub("<a href=", '<a target="_blank" rel="noopener noreferrer" href=', html, fixed = TRUE)
  shiny::HTML(html)
}

