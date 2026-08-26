library(shiny)
library(shinyjs)
library(leaflet)
library(RColorBrewer)
library(plyr)
library(tidyverse)
library(latticeExtra)
library(vegan)
library(plotly)
library(sp)
# library(rgdal)
library(ggthemes)
library(waffle)
library(shinyWidgets)
library(ggiraph)
library(ggrepel)
library(datamods)
#library(gganimate)

# Define server logic for slider examples
shinyServer(
  function(input, output, session) {
    
    # Descargar archivo Excel de folder www
    output$download_xlsx <- downloadHandler(
      filename = function() {
        "datos_phaseolus.xlsx"
      },
      content = function(file) {
        file.copy("www/PhaseolusEne2026_JE014_Unida.xlsx", file)
      },
      contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
    
    #Hacer interactivo el mapa
    shinyjs::onclick("mapa", 
                     shiny::updateNavbarPage(session, 
                                              inputId = "navbar",
                                              selected = "widgets"))
    
    #Hacer interactivo la altitud
    shinyjs::onclick("altitud", 
                     shiny::updateNavbarPage(session, 
                                             inputId = "navbar",
                                             selected = "widgets1"))
    
    #Hacer interactivo florecimiento
    shinyjs::onclick("crecimiento", 
                     shiny::updateNavbarPage(session, 
                                             inputId = "navbar",
                                             selected = "widgets3"))
    
    #Hacer interactivo waffle plot
    shinyjs::onclick("waffle", 
                     shiny::updateNavbarPage(session, 
                                             inputId = "navbar",
                                             selected = "widgets2"))
    
    
    output$inc <- renderUI({getPage()})
    

    
    # Filtros cruzados del mapa de Distribución (Condición, Estado, Especie).
    # Acota las opciones de cada selector según los demás y devuelve el data frame ya
    # filtrado — reemplaza el observeEvent de 7 combinaciones if/else + el reactive()
    # manual que había originalmente.
    #
    # Se usa datamods::select_group_server porque shinyWidgets marcó como obsoletas sus
    # selectizeGroupUI/selectizeGroupServer y las va a retirar. Diferencias de la API:
    #   - se llama directo, sin callModule (usa el patrón moduleServer moderno)
    #   - los argumentos son REACTIVOS: data_r y vars_r, no data y vars
    points <- select_group_server(
      id     = "my_filters",
      data_r = reactive(Mex3),
      vars_r = reactive(c("Habitat.1", "Estado", "Especie"))
    )
    
    
 #   map = leaflet()
 #   for (i in 1:length(providers)) {
 #     map = map %>% addProviderTiles(providers[i], group = providers[i])
 #   }
 #   
 #   map = map %>% addLayersControl(
 #     baseGroups = providers,
 #     options = layersControlOptions(collapsed = FALSE))
    
 #   map
    # Aplica el deslizador de altitud y la casilla de "sin altitud" encima de los
    # filtros de datamods.
    #
    # 855 de los 5,702 registros no tienen dato de altitud. Se manejan con dos reglas:
    #
    #  1. La casilla los quita explícitamente, si el usuario lo pide.
    #  2. Mientras el deslizador esté en su rango completo NO filtra nada. Sin esa
    #     guarda, una comparación como `Altitud >= min` los descartaría desde el
    #     arranque (NA nunca cumple una comparación) y desaparecerían del mapa sin
    #     que nadie hubiera tocado el control.
    #
    # Al acotar el rango sí se van, lo cual es correcto: no se sabe a qué altitud
    # pertenecen, así que no pueden afirmarse dentro de ninguna franja.
    points_altitud <- reactive({
      d <- points()
      if (isTRUE(input$sin_altitud)) d <- d[!is.na(d$Altitud), ]
      r <- input$altitud_mapa
      if (is.null(r) || (r[1] <= RANGO_ALTITUD_MAPA[1] && r[2] >= RANGO_ALTITUD_MAPA[2]))
        return(d)
      d[!is.na(d$Altitud) & d$Altitud >= r[1] & d$Altitud <= r[2], ]
    })

    output$mymap1 <- renderLeaflet({
      Tabla3 <- points_altitud()

      # Vector de colores NOMBRADO POR ESPECIE. Que esté nombrado es lo que hace que
      # cada especie conserve su color al filtrar: se busca por nombre, no por posición
      # dentro del subconjunto que quedó visible.
      colores <- colores_mapa(input$paleta_mapa)

      # Cambiar un filtro o la paleta reconstruye el mapa entero, lo que normalmente
      # devolvería la vista al encuadre inicial. Se lee el zoom y el centro actuales
      # para restaurarlos y que la persona no pierda dónde estaba mirando.
      # isolate() es IMPRESCINDIBLE: sin él, leer estos inputs —que el propio mapa
      # actualiza al moverse— crearía un ciclo infinito de redibujado.
      zoom_actual   <- isolate(input$mymap1_zoom)
      centro_actual <- isolate(input$mymap1_center)

      # zoomSnap = 0.25 permite niveles de zoom fraccionarios. Con el valor por defecto
      # (1) leaflet solo usa enteros, y como México cabe en 5.5 pero no en 6, redondeaba
      # a 5 y el país ocupaba apenas el 62% del ancho. Con 5.5 ocupa el 87%.
      # zoomDelta = 1 se deja explícito para que los botones + y − sigan moviéndose un
      # nivel completo y no de cuarto en cuarto.
      mapa <- leaflet(options = leafletOptions(zoomSnap = 0.25, zoomDelta = 1)) %>%
        # El fondo gris de Esri viene en DOS capas y las dos van en el grupo "Mapa"
        # para que se prendan y apaguen juntas: la base pone colores, relieve y agua,
        # pero NO rotula; los nombres de ciudades viven en World_Light_Gray_Reference
        # y hay que montarla encima a mano. Sin ella el mapa queda mudo.
        #
        # maxNativeZoom = 16 es imprescindible: las teselas de Esri se acaban en z16 y
        # sin él el fondo se queda EN BLANCO al pasar de ahí. Con él, leaflet estira la
        # tesela de z16 —se ve borrosa, pero se ve—, y para el detalle real a ese nivel
        # está la capa de "Foto aérea", que baja bastante más.
        #
        # Antes esto era CartoDB.Positron, hasta que CARTO empezó a estampar la marca
        # "API KEY REQUIRED" dentro del PNG de sus teselas gratuitas. La tesela responde
        # HTTP 200 y es una imagen válida, así que no hay error que capturar: la única
        # señal es la leyenda atravesada en el fondo. En local puede verse limpio por
        # caché; en incógnito aparece. Ver también la capa div_estatal más abajo.
        addProviderTiles(
          providers$Esri.WorldGrayCanvas, group = "Mapa",
          options = providerTileOptions(maxNativeZoom = 16, maxZoom = 19)) %>%
        addTiles(
          urlTemplate = paste0("https://server.arcgisonline.com/ArcGIS/rest/",
                               "services/Canvas/World_Light_Gray_Reference/",
                               "MapServer/tile/{z}/{y}/{x}"),
          group = "Mapa",
          options = tileOptions(maxNativeZoom = 16, maxZoom = 19),
          attribution = "Tiles &copy; Esri &mdash; Esri, DeLorme, NAVTEQ") %>%
        addProviderTiles(providers$Esri.WorldImagery, group = "Foto aérea") %>%
        # Las divisiones estatales van en su propio pane, entre el de las teselas (200)
        # y el de los vectores (overlayPane, 400): encima del fondo, debajo de los
        # puntos. OJO con el 405 que se usa en otros proyectos —ahí las capas de datos
        # son marcadores, que viven en el markerPane (600)— porque aquí los registros
        # son addCircles y esos caen en el overlayPane: con 405 las líneas quedarían
        # ENCIMA de los puntos de colecta.
        #
        # opacity = 1 es a propósito: con opacidad menor la línea se funde con el fondo
        # claro y el gris que se acaba viendo no es el del hex.
        addMapPane("division", zIndex = 250) %>%
        addPolylines(
          data = div_estatal,
          color = "#ADADAD", weight = 0.8, opacity = 1,
          options = pathOptions(pane = "division", interactive = FALSE)) %>%
        addCircles(data = Tabla3, group = "Circles",
                   lng = ~Longitud, lat = ~Latitud,
                   color = unname(colores[as.character(Tabla3$Especie)]),
                   weight = 5, opacity = 0.7,
                   popup = ~paste(sep = " ", "Especie:",Tabla3$Taxa,
                                  "<br/>", "Condición:",Tabla3$Habitat.1,
                                  "<br/>", "Estado:",Tabla3$Estado,
                                  "<br/>", "Municipio:",Tabla3$Municipio,
                                  "<br/>", "Localidad:",Tabla3$Localidad,
                                  "<br/>", "Altitud:",Tabla3$Altitud, "metros",
                                  "<br/>", "Año de colecta:", Tabla3$AnioColecta)) %>%
        addLayersControl(
          baseGroups = c("Mapa", "Foto aérea"),
          position = "topright",
          options = layersControlOptions(collapsed = FALSE))

      if (!is.null(zoom_actual) && !is.null(centro_actual)) {
        mapa <- mapa %>% setView(lng = centro_actual$lng, lat = centro_actual$lat,
                                 zoom = zoom_actual)
      } else {
        # Encuadre inicial: se ajusta al total de registros (todos en México, desde
        # Baja California hasta Chiapas). El padding evita que los puntos del borde
        # queden cortados a la mitad.
        mapa <- mapa %>% fitBounds(
          min(Mex3$Longitud, na.rm = TRUE), min(Mex3$Latitud, na.rm = TRUE),
          max(Mex3$Longitud, na.rm = TRUE), max(Mex3$Latitud, na.rm = TRUE),
          options = list(padding = c(15, 15)))
      }
      mapa
    })
 
  #Para la Floración    
    observeEvent(
      input$Estado1,
        updateSelectInput(session, inputId = "Especie1", label = "Especie:", 
                          choice = c("All" ,levels(droplevels(Mex3$Especie[Mex3$Estado %in% input$Estado1])))))
    
    #Para las epocas de lluvia y Floración
    points1 <- reactive({
      #Epoca — "Ambas" no filtra: deja pasar las dos para poder dibujarlas encimadas
      if (!identical(input$Epoca, AMBAS_EPOCAS)) {
        FloFru <- FloFru[FloFru$Epoca %in% input$Epoca,]
      }
      #Tipo
      FloFru <- FloFru[FloFru$Tipo %in% input$Tipo,]
    })
    

FloFru1_data <- reactive({
  FloFru1 <- points1() %>%
    gather("Mes", "Val", 8:19) %>%
    rename("Categoria" = "NombreCategoriaTaxonomica") %>%
    rename("Genero1" = "Nombre_1_Nombre") %>%
    rename("Especie1" = "Nombre_Nombre") %>%
    # Epoca entra al agrupamiento para que con "Ambas" las dos no se fundan en un
    # solo valor por celda. Con una época sola no cambia nada: solo hay un nivel.
    group_by(Epoca, Genero1, Especie1, Mes) %>%
    summarise(sum(Val)) %>%
    rename(Val = `sum(Val)`) %>%
    unite(Genero1, Especie1, col = "Especie", sep = " ")

  FloFru1$Mes <- as.factor(FloFru1$Mes)

  FloFru1$Mes <- ordered(FloFru1$Mes, levels = c("Enero", "Febrero", "Marzo",
                                                 "Abril", "Mayo", "Junio",
                                                 "Julio", "Agosto", "Septiembre",
                                                 "Octubre", "Noviembre", "Diciembre"))

  # Se renombran los niveles a la forma corta (Ene, Feb, ...) en vez de usar
  # labels= en scale_x_discrete, porque combinar labels= con sec.axis/dup_axis()
  # en una escala discreta provoca el error "breaks and labels have different lengths"
  levels(FloFru1$Mes) <- c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
                           "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")
  FloFru1
})

# Altura en píxeles según el número de especies (mínimo 600) — se usa tanto para
# dimensionar el contenedor en la UI como para generar la imagen del mismo tamaño
alto_graph4 <- reactive({
  # 28 px por especie MÁS un margen fijo para el título y los dos ejes de meses.
  # Antes era max(600, n * 28), y ese piso de 600 deformaba la gráfica: con
  # Silvestres (55 especies) cada renglón medía 28 px, pero con Cultivados (5) el
  # alto se quedaba en 600 y cada cuadro crecía a 120 px. El margen va SUMADO, no
  # como mínimo, para que el renglón mida siempre lo mismo sin importar el filtro.
  # Los 70 px del margen se midieron en el navegador comparando el alto del SVG contra
  # el alto real de los cuadros: es lo que ocupan el título y los dos ejes de meses,
  # y no cambia con el número de especies.
  # Con las dos épocas se suman una leyenda y un subtítulo arriba, que el margen de
  # 70 px no contemplaba. Sin este extra le robaban alto a los renglones.
  margen <- if (identical(input$Epoca, AMBAS_EPOCAS)) 70 + 60 else 70
  max(150, length(unique(FloFru1_data()$Especie)) * 28 + margen)
})

output$graph4 <- renderGirafe({

  FloFru1 <- FloFru1_data()

  ambas <- identical(input$Epoca, AMBAS_EPOCAS)

  # El título se arma con los filtros activos, ej.:
  # "Época de floración de los frijoles silvestres"
  titulo_graph4 <- paste0(
    "Época de ",
    if (ambas) "floración y fructificación" else tolower(input$Epoca),
    " de los frijoles ", tolower(input$Tipo))

  # Tema y ejes son iguales en los dos modos; lo único que cambia es cómo se pinta
  # cada celda, así que se definen una sola vez.
  tema_graph4 <- list(
    labs(title = titulo_graph4, x = NULL, y = NULL),
    theme_minimal(),
    theme(panel.border = element_blank(),
          panel.grid = element_blank(),
          plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
          plot.subtitle = element_text(size = 12, colour = "#525252", hjust = 0.5),
          axis.text.y = element_text(size = 12, face = "italic"),
          axis.text.x = element_text(angle = 0, size = 12, hjust = 0.5, vjust = 0.5),
          legend.position = if (ambas) "top" else "",
          legend.title = element_blank(),
          legend.text = element_text(size = 13)))

  if (!ambas) {
    # ---- Una sola época: la vista de siempre ----
    # Color elegido por el usuario (paleta FantasticFox1). El extremo claro del
    # degradado se deriva aclarando el mismo color, para que combinen.
    color_alto <- unname(paleta_fox[input$color_fox])
    color_bajo <- colorspace::lighten(color_alto, 0.85)

    # data_id = Especie hace que al pasar el mouse por cualquier mes de una especie
    # se resalte su renglón completo, y el resto se atenúe.
    p <- ggplot(FloFru1, aes(Mes, Especie)) +
      geom_tile_interactive(
        aes(fill = Val, data_id = Especie,
            tooltip = paste0(Especie, "\n", Mes)),
        colour = "white") +
      scale_fill_gradient(low = color_bajo, high = color_alto) +
      # duplica el eje de los meses para que aparezcan arriba y abajo
      scale_x_discrete(sec.axis = dup_axis()) +
      tema_graph4

  } else {
    # ---- Las dos épocas encimadas ----
    # Cada época se dibuja como un triángulo rectángulo dentro de su celda: floración
    # arriba-izquierda, fructificación abajo-derecha, partidas por la diagonal que va
    # de la esquina inferior izquierda a la superior derecha. Las dos mitades juntas
    # reconstruyen el cuadro completo, así que un mes con las dos épocas se ve como una
    # celda dividida en diagonal, y un mes con una sola se ve medio lleno. No hace falta
    # una regla aparte para el caso "ambas": sale solo de dibujar cada época por su lado.
    #
    # Los ejes pasan a ser CONTINUOS (no discretos) porque geom_polygon necesita
    # coordenadas numéricas para los vértices. De paso evita la trampa documentada de
    # combinar labels= con dup_axis() en una escala discreta.
    # Un color por época, de la misma paleta FantasticFox1 que la otra vista. Si el
    # usuario elige el mismo para las dos, la celda con ambas épocas se ve sólida: es
    # su decisión y no se corrige, pero por eso los valores de arranque son dos
    # colores que contrastan (ver colores_epoca_default en global.R).
    colores_epoca <- c(
      "Floración"      = unname(paleta_fox[input$color_flo]),
      "Fructificación" = unname(paleta_fox[input$color_fru])
    )

    meses       <- levels(FloFru1$Mes)
    esp_niveles <- sort(unique(FloFru1$Especie))   # mismo orden que daba el eje discreto

    FloFru1$xi <- as.integer(FloFru1$Mes)
    FloFru1$yi <- match(FloFru1$Especie, esp_niveles)

    presentes <- FloFru1[FloFru1$Val > 0, ]
    MEDIA <- 0.45   # media celda; el resto queda como separación, igual que el borde
                    # blanco que geom_tile dibujaba en la otra vista

    # Un triángulo son 3 vértices; `group` los une y debe ser único en toda la capa,
    # por eso el id lleva el nombre de la época como prefijo.
    triangulos <- do.call(rbind, lapply(EPOCAS, function(ep) {
      d <- presentes[presentes$Epoca == ep, ]
      if (nrow(d) == 0) return(NULL)
      dx <- if (ep == "Floración") c(-1, -1,  1) else c(-1,  1,  1)
      dy <- if (ep == "Floración") c(-1,  1,  1) else c(-1, -1,  1)
      data.frame(
        grupo   = rep(paste0(ep, "_", seq_len(nrow(d))), each = 3),
        x       = rep(d$xi, each = 3) + rep(dx, nrow(d)) * MEDIA,
        y       = rep(d$yi, each = 3) + rep(dy, nrow(d)) * MEDIA,
        Epoca   = factor(ep, levels = EPOCAS),
        Especie = rep(d$Especie, each = 3),
        tip     = rep(paste0(d$Especie, "\n", d$Mes, " — ", ep), each = 3)
      )
    }))

    # Fondo tenue en todas las celdas: mantiene visible la rejilla completa, para que
    # se note dónde NO hay dato en vez de dejar huecos que parezcan margen.
    fondo <- unique(FloFru1[, c("xi", "yi")])

    p <- ggplot() +
      geom_tile(data = fondo, aes(x = xi, y = yi),
                fill = "#F4F4F4", width = 0.9, height = 0.9) +
      geom_polygon_interactive(
        data = triangulos,
        aes(x = x, y = y, group = grupo, fill = Epoca,
            data_id = Especie, tooltip = tip),
        colour = NA) +
      scale_fill_manual(values = colores_epoca, drop = FALSE) +
      scale_x_continuous(breaks = seq_along(meses), labels = meses,
                         sec.axis = dup_axis(), expand = expansion(add = 0.5)) +
      scale_y_continuous(breaks = seq_along(esp_niveles), labels = esp_niveles,
                         expand = expansion(add = 0.5)) +
      labs(subtitle = "Las celdas partidas en diagonal son los meses con las dos épocas") +
      tema_graph4
  }

  girafe(
    ggobj = p,
    width_svg = 12,
    height_svg = alto_graph4() / 72,
    options = list(
      opts_hover(css = "stroke:#333333; stroke-width:1.5pt;"),
      opts_hover_inv(css = "opacity:0.35;"),
      opts_tooltip(css = "background-color:#333; color:#fff; padding:5px;
                          border-radius:4px; font-size:12px;"),
      # hidden = "selection" quita los dos botones de lazo, que no se usan.
      # Se conservan el zoom, la descarga en PNG y la pantalla completa.
      opts_toolbar(saveaspng = TRUE, pngname = "floracion_fructificacion",
                   hidden = "selection"),
      opts_sizing(rescale = TRUE)
    )
  )
})
    
  #Para la Altitud
    # Rangos altitudinales por especie, filtrados por los estados elegidos.
    # Los registros de todos los estados seleccionados se agrupan juntos: el mínimo
    # es el más bajo de la selección, el máximo el más alto, y el promedio la media
    # de todos los registros individuales (queda ponderado por número de colectas).
    Mex10 <- reactive({
      req(input$Estado_alt)
      d <- Mex3[Mex3$Estado %in% input$Estado_alt, ]
      L <- suppressWarnings(
        d %>%
          dplyr::select(Especie, Altitud) %>%
          dplyr::group_by(Especie) %>%
          dplyr::summarise(minimo = min(Altitud, na.rm = TRUE),
                           prom   = mean(Altitud, na.rm = TRUE),
                           maximo = max(Altitud, na.rm = TRUE),
                           .groups = "drop")
      ) %>%
        dplyr::filter(is.finite(minimo), is.finite(maximo), is.finite(prom))

      L$ordenar <- switch(input$var11,
                          "promedio" = L$prom,
                          "máximo"   = L$maximo,
                          "mínimo"   = L$minimo)
      L <- L[order(L$ordenar), ]
      L$pos <- seq_len(nrow(L))
      # Etiqueta abreviada: "Phaseolus vulgaris" -> "P. vulgaris" (ver global.R)
      L$etiqueta <- abreviar_especie(L$Especie)
      L
    })

    DESPEGUE <- 200  # metros que el nombre se levanta sobre su propio valor

    # Alto de la gráfica: ~15 px por especie es lo que necesita un renglón de texto
    alto_graph2 <- reactive({
      LL <- Mex10()
      if (nrow(LL) == 0) return(600)
      max(650, nrow(LL) * 15 + 130)
    })

    ####
    # Perfil altitudinal al estilo del "Perfil de vegetación y fauna" del Atlas
    # Nacional de España: silueta de montaña de fondo, un punto por especie a la
    # altitud elegida (promedio, máximo o mínimo) y su nombre al lado, alternando
    # izquierda/derecha. Se dibuja con ggiraph para que al pasar el mouse por una
    # especie se resalten su punto, su línea y su nombre a la vez.
    output$graph2 <- renderGirafe({
      LL <- Mex10()
      validate(need(nrow(LL) > 0,
                    "No hay datos de altitud para los estados seleccionados."))

      n <- nrow(LL)

      # La montaña se dibuja en TRES capas anidadas (mínimo, promedio y máximo), para
      # que se vea de un vistazo toda la franja altitudinal que ocupa el género.
      #
      # La ladera de la variable ELEGIDA en el selector va exacta, sin suavizar, para
      # que cada punto quede posado sobre su superficie. Las otras dos se suavizan:
      # al no ser el criterio de orden, saltan bruscamente entre especies vecinas y
      # sin suavizar salen como una sierra de picos que arruina la figura.
      suavizar <- function(v) {
        if (length(v) < 5) return(pmax(v, 0))
        pmax(stats::predict(stats::loess(v ~ LL$pos, span = 0.5)), 0)
      }
      cresta_min  <- if (input$var11 == "mínimo")   LL$minimo else suavizar(LL$minimo)
      cresta_prom <- if (input$var11 == "promedio") LL$prom   else suavizar(LL$prom)
      cresta_max  <- if (input$var11 == "máximo")   LL$maximo else suavizar(LL$maximo)

      # Al suavizar por separado, las curvas podrían cruzarse. Se fuerza que se respete
      # mínimo <= promedio <= máximo, pero ajustando SIEMPRE las suavizadas y nunca la
      # exacta: si se moviera la exacta, los puntos dejarían de posarse sobre ella.
      if (input$var11 == "máximo") {
        cresta_prom <- pmin(cresta_prom, cresta_max)
        cresta_min  <- pmin(cresta_min,  cresta_prom)
      } else if (input$var11 == "mínimo") {
        cresta_prom <- pmax(cresta_prom, cresta_min)
        cresta_max  <- pmax(cresta_max,  cresta_prom)
      } else {                                   # promedio
        cresta_min <- pmin(cresta_min, cresta_prom)
        cresta_max <- pmax(cresta_max, cresta_prom)
      }

      poligono <- function(cresta) {
        data.frame(x = c(0.3, LL$pos, n + 0.7), y = c(0, cresta, 0))
      }

      # Espacio libre arriba para que ggrepel tenga a dónde mover los nombres
      techo <- max(LL$ordenar) + DESPEGUE * 3

      # Color de cada nombre. Se guarda como columna con el color literal y se pinta con
      # scale_colour_identity(): pasar un vector al parámetro `colour` funciona, pero
      # depende de que las filas queden en el mismo orden, y ggrepel las reacomoda.
      # Atándolo a los datos con aes() no hay forma de que se despareje.
      resaltar <- isTRUE(input$domesticadas) &
        as.character(LL$Especie) %in% especies_domesticadas
      LL$color_nombre <- ifelse(resaltar, "#B40F20", "grey15")
      # "bold.italic" y no "bold": la cursiva se conserva siempre, porque es la
      # convención tipográfica para los nombres científicos.
      LL$face_nombre  <- ifelse(resaltar, "bold.italic", "italic")

      # Los nombres se alternan: uno tiende hacia la izquierda de su punto y el
      # siguiente hacia la derecha. Ya no es una posición fija sino un sesgo que se le
      # pasa a ggrepel (nudge_x), porque él decide la posición final para evitar choques.
      LL$lado <- ifelse(LL$pos %% 2 == 1, -1, 1)

      # Líneas de referencia de las capitales elegidas. Se dibujan primero para que
      # queden por debajo de los datos y no los tapen.
      caps <- capitales_altitud[capitales_altitud$ciudad %in% input$capitales, ]
      caps <- caps[caps$altitud <= techo, ]   # por si alguna sale del rango visible
      capa_capitales <- if (nrow(caps) > 0) {
        list(
          geom_hline(data = caps, aes(yintercept = altitud),
                     colour = "#1F6F8B", linewidth = 0.5, linetype = "longdash"),
          # x = -Inf ancla la etiqueta al borde izquierdo del panel
          geom_label(data = caps,
                     aes(x = -Inf, y = altitud,
                         label = paste0(ciudad, " · ", altitud, " m")),
                     hjust = 0, vjust = -0.25, size = 4, colour = "#1F6F8B",
                     fill = "white", linewidth = 0, label.padding = unit(1.2, "pt"))
        )
      } else NULL

      # Se usan los geoms *_interactive de ggiraph con un data_id común por especie:
      # al pasar el mouse por el punto, su línea punteada o su nombre, los tres se
      # resaltan a la vez (el estilo del resaltado se define en girafe(), más abajo).
      uno <- ggplot() +
        # de la más clara (máximo) a la más oscura (mínimo), para que queden anidadas
        geom_polygon(data = poligono(cresta_max),  aes(x, y), fill = "#F7EFE0", colour = NA) +
        geom_polygon(data = poligono(cresta_prom), aes(x, y), fill = "#E8D5B0", colour = NA) +
        geom_polygon(data = poligono(cresta_min),  aes(x, y), fill = "#CBB185", colour = NA) +
        capa_capitales +
        geom_point_interactive(
          data = LL,
          aes(x = pos, y = ordenar, data_id = Especie,
              tooltip = paste0(Especie, "\n", round(ordenar), " m")),
          colour = "grey20", size = 1.8) +
        # ggrepel reacomoda los nombres que se encimarían y dibuja él mismo la línea
        # guía hasta su punto, así la línea sigue al nombre cuando lo tiene que mover.
        # nudge_x los sesga al lado que les toca (se conserva el alternado izq/der) y
        # nudge_y los levanta DESPEGUE metros sobre su punto.
        geom_text_repel_interactive(
          data = LL,
          aes(x = pos, y = ordenar, label = etiqueta,
              data_id = Especie, colour = color_nombre, fontface = face_nombre,
              tooltip = paste0(Especie, "\n", round(ordenar), " m")),
          nudge_x = LL$lado * 0.6,
          nudge_y = DESPEGUE,
          size = 4,
          segment.colour = "grey45", segment.linetype = "dashed",
          segment.size = 0.4,
          min.segment.length = 0,   # que siempre dibuje la línea guía
          box.padding = 0.3, point.padding = 0.2,
          max.overlaps = Inf,       # IMPRESCINDIBLE: si no, descarta nombres en silencio
          seed = 42) +              # para que el acomodo sea reproducible
        # Usan el color y el estilo literales que traen las columnas, sin inventar
        # una paleta ni una leyenda
        scale_colour_identity() +
        scale_discrete_identity(aesthetics = "fontface") +
        # Contador de especies visibles, arriba a la izquierda: es la zona vacía de la
        # figura, porque la montaña asciende de izquierda a derecha. Cambia al mover el
        # filtro de estados.
        # Se ancla a la ALTURA DE LA ESPECIE MÁS ALTA (no al borde del panel) para que
        # se lea como parte de la gráfica y no como una tercera línea del título.
        # Va al final del + para quedar dibujado ENCIMA de todo: ggrepel no sabe que
        # existe y podría mandar un nombre a esa esquina.
        annotate("text", x = -Inf, y = max(LL$ordenar), label = n,
                 hjust = -0.25, vjust = 0.5,
                 size = 20, fontface = "bold", colour = "#7A5C2E") +
        annotate("text", x = -Inf, y = max(LL$ordenar),
                 label = if (n == 1) "especie" else "especies",
                 # vjust se mide en altos de SU PROPIA letra, no de la del número:
                 # por eso hace falta un valor grande para librar los dígitos
                 hjust = -0.32, vjust = 4,
                 size = 6, colour = "#7A5C2E") +
        scale_y_continuous(breaks = seq(0, 3000, 1000),
                           labels = paste0(seq(0, 3000, 1000), " m"),
                           limits = c(0, techo), expand = c(0, 0)) +
        # aire a ambos lados, porque los nombres salen alternados
        scale_x_continuous(expand = expansion(mult = c(0.13, 0.13))) +
        labs(title = "Rangos altitudinales de los frijoles",
             subtitle = paste0("Cada punto marca la altitud ",
                               switch(input$var11,
                                      "promedio" = "promedio",
                                      "máximo"   = "máxima",
                                      "mínimo"   = "mínima"),
                               " de la especie\n",
                               "Las bandas de la montaña muestran el rango altitudinal: ",
                               "mínimo (tono oscuro), promedio y máximo (tono claro)",
                               # solo aparece cuando el resaltado está activo, para que
                               # la figura se explique sola si alguien la exporta
                               if (isTRUE(input$domesticadas))
                                 "\nEn rojo y negritas, las especies domesticadas"
                               else ""),
             x = NULL, y = NULL) +
        theme_minimal() +
        theme(plot.title = element_text(size = 18, face = "bold", hjust = 0.5),
              plot.subtitle = element_text(size = 16, colour = "grey40", hjust = 0.5),
              panel.grid.major.x = element_blank(),
              panel.grid.minor = element_blank(),
              panel.grid.major.y = element_line(colour = "grey88", linetype = "dashed"),
              axis.text.x = element_blank(),
              axis.ticks.x = element_blank(),
              axis.text.y = element_text(size = 12),
              legend.position = "none")

      # Se entrega como SVG interactivo. hover_css aplica al elemento bajo el mouse y
      # a todos los que comparten su data_id, así que resalta punto + línea + nombre.
      girafe(
        ggobj = uno,
        width_svg = 12,
        height_svg = alto_graph2() / 72,
        options = list(
          opts_hover(css = "fill:#B40F20; stroke:#B40F20; stroke-width:1.2pt;"),
          opts_hover_inv(css = "opacity:0.30;"),
          opts_tooltip(css = "background-color:#333; color:#fff; padding:5px;
                              border-radius:4px; font-size:12px;"),
          # hidden = "selection" quita los dos botones de lazo, que no se usan.
          # Se conservan el zoom, la descarga en PNG y la pantalla completa.
          opts_toolbar(saveaspng = TRUE, pngname = "altitud_global",
                       hidden = "selection"),
          opts_sizing(rescale = TRUE)
        )
      )
    })

  # ---- Altitud por especie -------------------------------------------------
  # Igual que la pestaña de Altitud pero SIN resumir: en vez de un punto por especie
  # (su promedio, máximo o mínimo), se dibuja el gradiente completo — cada altitud
  # donde se ha registrado esa especie.
  #
  # Cada especie tiene su propia montaña y el eje X es el PORCENTAJE de sus registros,
  # no un conteo. Eso es lo que permite comparar especies con volúmenes muy distintos:
  # P. vulgaris tiene 300 altitudes distintas y P. dumosus 40, pero ambas curvas van de
  # 0 a 100% y se pueden leer una contra otra.
    Mex11 <- reactive({
      req(input$especies_alt)
      d <- Mex3[!is.na(Mex3$Altitud) &
                  as.character(Mex3$Especie) %in% input$especies_alt, ]
      # distinct(): una misma altitud repetida en decenas de colectas aporta un solo
      # punto. Sin esto, P. vulgaris dibujaría 1387 puntos encimados en vez de 300.
      d <- dplyr::distinct(d, Especie, Altitud, .keep_all = TRUE)
      d$Especie <- droplevels(factor(as.character(d$Especie)))
      d %>%
        dplyr::group_by(Especie) %>%
        dplyr::arrange(Altitud, .by_group = TRUE) %>%
        # con una sola altitud no hay gradiente que recorrer: se coloca al centro
        dplyr::mutate(pct = if (dplyr::n() > 1)
          (dplyr::row_number() - 1) / (dplyr::n() - 1) * 100 else 50) %>%
        dplyr::ungroup()
    })

    alto_graph5 <- reactive({
      # alto fijo: a diferencia de Altitud, aquí el número de renglones no crece con
      # los datos, solo se acumulan curvas sobre el mismo espacio
      700
    })

    output$graph5 <- renderGirafe({
      D <- Mex11()
      validate(need(nrow(D) > 0,
                    "No hay datos de altitud para las especies seleccionadas."))

      # Los colores se asignan por posición entre las especies ELEGIDAS, tomando la
      # Paleta 2 del mapa, que está ordenada de mayor a menor contraste. Así los
      # primeros colores son siempre los más distinguibles entre sí.
      cols <- setNames(rep_len(paletas_mapa[["Paleta 2"]], nlevels(D$Especie)),
                       levels(D$Especie))
      # la leyenda usa el nombre abreviado; el tooltip conserva el completo
      etiquetas <- setNames(abreviar_especie(levels(D$Especie)), levels(D$Especie))

      techo <- max(D$Altitud) * 1.12

      caps <- capitales_altitud[capitales_altitud$ciudad %in% input$capitales2, ]
      caps <- caps[caps$altitud <= techo, ]
      capa_capitales <- if (nrow(caps) > 0) {
        list(
          geom_hline(data = caps, aes(yintercept = altitud),
                     colour = "#1F6F8B", linewidth = 0.5, linetype = "longdash"),
          geom_label(data = caps,
                     aes(x = -Inf, y = altitud,
                         label = paste0(ciudad, " · ", altitud, " m")),
                     hjust = 0, vjust = -0.25, size = 4, colour = "#1F6F8B",
                     fill = "white", linewidth = 0, label.padding = unit(1.2, "pt"))
        )
      } else NULL

      cinco <- ggplot(D, aes(x = pct, y = Altitud)) +
        # el área rellena convierte cada curva en una "montaña", igual que en Altitud
        geom_area(aes(group = Especie, fill = Especie),
                  position = "identity", alpha = 0.22, colour = NA) +
        capa_capitales +
        # data_id = Especie: al pasar el mouse por cualquier punto se resalta el
        # gradiente completo de esa especie y se atenúan las demás
        geom_point_interactive(
          aes(colour = Especie, data_id = Especie,
              tooltip = paste0(Especie, "\n", round(Altitud), " m")),
          size = 1.2, alpha = 0.9) +
        scale_colour_manual(values = cols, labels = etiquetas, name = NULL) +
        scale_fill_manual(values = cols, guide = "none") +
        scale_y_continuous(labels = function(x) paste0(x, " m"),
                           limits = c(0, techo), expand = c(0, 0)) +
        scale_x_continuous(labels = function(x) paste0(x, "%"),
                           limits = c(0, 100), expand = expansion(mult = c(0.02, 0.02))) +
        labs(title = "Gradiente altitudinal por especie",
             subtitle = paste0("Cada punto es una altitud donde se ha registrado la ",
                               "especie, de la más baja a la más alta\n",
                               "El eje horizontal es el porcentaje de los registros de ",
                               "cada especie, para poder compararlas entre sí"),
             caption = paste0("Solo se incluyen las especies con más de ",
                              MIN_ALTITUDES_GRADIENTE - 1,
                              " altitudes distintas registradas (",
                              length(especies_con_gradiente), " de ",
                              nlevels(droplevels(Mex3$Especie[!is.na(Mex3$Altitud)])),
                              "): con menos no hay gradiente que mostrar."),
             x = NULL, y = NULL) +
        theme_minimal() +
        theme(plot.title = element_text(size = 18, face = "bold", hjust = 0.5),
              plot.subtitle = element_text(size = 14, colour = "grey40", hjust = 0.5),
              panel.grid.minor = element_blank(),
              panel.grid.major.y = element_line(colour = "grey88", linetype = "dashed"),
              axis.text = element_text(size = 12),
              plot.caption = element_text(colour = "grey45", hjust = 0, size = 11,
                                          face = "italic"),
              plot.caption.position = "plot",
              legend.position = "top",
              legend.text = element_text(size = 13, face = "italic"))

      girafe(
        ggobj = cinco,
        width_svg = 12,
        height_svg = alto_graph5() / 72,
        options = list(
          opts_hover(css = "fill:#B40F20; stroke:#B40F20; stroke-width:1.2pt;"),
          opts_hover_inv(css = "opacity:0.25;"),
          opts_tooltip(css = "background-color:#333; color:#fff; padding:5px;
                              border-radius:4px; font-size:12px;"),
          # hidden = "selection" quita los dos botones de lazo, que no se usan.
          # Se conservan el zoom, la descarga en PNG y la pantalla completa.
          opts_toolbar(saveaspng = TRUE, pngname = "altitud_por_especie",
                       hidden = "selection"),
          opts_sizing(rescale = TRUE)
        )
      )
    })

    #
    points2 <- reactive({
      #input$update
      
      #Por Estado
      
      if (input$Estado2 != "All") {
        Mex3 <- Mex3[Mex3$Estado %in% input$Estado2,]
      } else Mex3 <- Mex3
      
    })
    
    output$graph3 <- renderGirafe({

      Tabla6a <- points2()

      TTabla1 <- Tabla6a %>%
        dplyr::count(Especie) %>%
        mutate(pct_real = n/sum(n)*100,          # porcentaje exacto, para el tooltip
               val1 = round(n/sum(n)*100)) %>%
        arrange(-val1, -pct_real)

      Diff <- 100 - sum(TTabla1$val1)
      TTabla1$val1[1] <- TTabla1$val1[1] + Diff

      validate(need(sum(TTabla1$val1) > 0,
                    "No hay registros para el estado seleccionado."))

      # Todas las especies conservan color y entrada en la leyenda, incluidas las
      # raras: son las que redondean a 0% y no alcanzan a ocupar ni un cuadro del
      # waffle.
      TTabla1$Especie <- factor(TTabla1$Especie, levels = TTabla1$Especie)
      # paleta NOMBRADA por especie: el cuadro multicolor la consulta por nombre,
      # no por posición, así que no se desfasa al reacomodar la rejilla
      mypalette <- colores_waffle(input$paleta_waffle, nrow(TTabla1))
      names(mypalette) <- levels(TTabla1$Especie)

      # Modo de color. La rejilla NO cambia entre modos: se sigue armando por especie
      # y en el mismo orden, así que al cambiar el selector la figura se recolorea sin
      # reacomodarse y las dos vistas son comparables cuadro por cuadro.
      por_especie <- !identical(input$color_waffle, "Domesticadas y silvestres")

      comunes <- TTabla1[TTabla1$val1 > 0, ]
      raras   <- TTabla1[TTabla1$val1 == 0, ]

      # Las especies que no alcanzan un cuadro propio no desaparecen: se juntan en un
      # solo cuadro MULTICOLOR dentro de la rejilla, dividido en una franja por especie.
      # Así siguen siendo parte visible del 100%, que era la crítica al diseño anterior
      # (si son parte del universo de frijoles, deberían verse en la figura).
      #
      # Para hacerle lugar se le quita un cuadro a la especie más pequeña de la rejilla.
      # Si con eso se queda en cero, esa especie baja también al grupo del multicolor:
      # tiene menos de 1% real, así que pertenece más a ese grupo que al resto.
      excluidas <- raras
      if (nrow(raras) > 0) {
        u <- nrow(comunes)
        comunes$val1[u] <- comunes$val1[u] - 1
        if (comunes$val1[u] == 0) {
          excluidas <- rbind(comunes[u, ], raras)
          comunes   <- comunes[-u, ]
        }
      }

      # El waffle se arma a mano en vez de usar waffle(): esa función genera sus
      # propios geoms internos, que no son interactivos. Reconstruir la rejilla
      # permite usar geom_tile_interactive y que al pasar el mouse por un cuadro se
      # resalten todos los de esa especie (y su entrada en la leyenda).
      FILAS <- 10
      celdas <- data.frame(
        Especie = factor(rep(as.character(comunes$Especie), comunes$val1),
                         levels = levels(TTabla1$Especie))
      )
      idx <- seq_len(nrow(celdas)) - 1
      celdas$fila    <- idx %% FILAS          # se llena por columnas, de abajo hacia arriba
      celdas$columna <- idx %/% FILAS
      celdas$tip <- paste0(celdas$Especie, "\n",
                           comunes$val1[match(celdas$Especie, comunes$Especie)],
                           "% de los registros")

      # El cuadro multicolor va en la celda que quedó libre, la siguiente de la rejilla.
      # Se arma con un geom_rect por especie, todos dentro del mismo cuadro; encima se
      # dibuja un marco blanco para que se vea del mismo tamaño que los demás.
      # inherit.aes = FALSE es IMPRESCINDIBLE: sin él hereda el aes(x = columna) global
      # y falla porque estos datos no tienen esa columna.
      capa_multicolor <- NULL
      if (nrow(excluidas) > 0) {
        k  <- nrow(celdas)
        cx <- k %/% FILAS
        cy <- k %%  FILAS
        ne <- nrow(excluidas)
        tip_multi <- paste0("Todas juntas: ",
                            sprintf("%.1f", sum(excluidas$pct_real)),
                            "% de los registros\n",
                            paste(abreviar_especie(excluidas$Especie), collapse = ", "))
        franjas <- data.frame(
          xmin    = cx - 0.45 + (0:(ne - 1)) * (0.9 / ne),
          xmax    = cx - 0.45 + (1:ne)       * (0.9 / ne),
          ymin    = cy - 0.45,
          ymax    = cy + 0.45,
          Especie = excluidas$Especie,
          tip     = tip_multi
        )
        # data_id sigue siendo la especie en ambos modos, así que pasar el mouse por
        # una franja resalta esa especie y su cuadro de la fila de abajo
        franjas$relleno <- if (por_especie) franjas$Especie
                           else grupo_domesticacion(franjas$Especie)
        capa_multicolor <- list(
          geom_rect_interactive(
            data = franjas,
            aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax,
                fill = relleno, tooltip = tip, data_id = Especie),
            colour = NA, inherit.aes = FALSE),
          annotate("rect", xmin = cx - 0.45, xmax = cx + 0.45,
                   ymin = cy - 0.45, ymax = cy + 0.45,
                   fill = NA, colour = "white", linewidth = 0.8)
        )
      }

      # Fila aparte, debajo de la rejilla, con cada una de las especies del multicolor
      # por separado, para poder verlas y consultarlas una por una
      FILA_RARAS <- -2.2
      if (nrow(excluidas) > 0) {
        celdas_raras <- data.frame(
          Especie = excluidas$Especie,
          fila    = FILA_RARAS,
          columna = seq_len(nrow(excluidas)) - 1,
          tip     = paste0(excluidas$Especie, "\nmenos del 1% de los registros (",
                           sprintf("%.2f", excluidas$pct_real), "%)")
        )
        celdas <- rbind(celdas, celdas_raras)
      }

      # Nota al pie que explica el cuadro multicolor.
      # Al colorear por condición ese cuadro deja de ser multicolor —sus franjas se
      # pintan con solo dos colores y suele verse casi sólido—, así que se le nombra
      # por su posición en vez de por su aspecto.
      #
      # El texto se parte a un ancho fijo en vez de dejarlo en dos renglones largos.
      # Medido en el navegador: la nota se salía del contenedor y se cortaba —15 px al
      # colorear por especie y 96 px por condición—. La causa es coord_equal(): fija el
      # ancho del panel, así que el espacio sobrante recentra la figura y la recorre a
      # la derecha, y cuánto se recorre depende de qué tan ancha sea la leyenda (varía
      # con el número de especies del estado y con el modo de color). Envolver el texto
      # lo resuelve para todos los casos sin depender de ese ancho.
      ANCHO_NOTA <- 100   # caracteres
      nota_raras <- if (nrow(excluidas) > 0) {
        partes <- c(
          paste0("El ", if (por_especie) "cuadro multicolor" else "último cuadro",
                 " de la rejilla representa en conjunto a las especies ",
                 "que no alcanzan un cuadro propio (",
                 sprintf("%.1f", sum(excluidas$pct_real)),
                 "% de los registros), y abajo se muestran una por una:"),
          # la lista de especies arranca en renglón propio, por eso se envuelve aparte
          paste0(paste(abreviar_especie(excluidas$Especie), collapse = ", "), ".")
        )
        paste(unlist(lapply(partes, strwrap, width = ANCHO_NOTA)), collapse = "\n")
      } else NULL

      # El relleno se resuelve al final, ya armada la rejilla (incluida la fila de las
      # especies del multicolor), para que ambos modos partan exactamente de las mismas
      # celdas. data_id y tooltip NO cambian: siguen siendo por especie en los dos modos.
      celdas$relleno <- if (por_especie) celdas$Especie
                        else grupo_domesticacion(celdas$Especie)

      escala_relleno <- if (por_especie) {
        # labels solo abrevia lo que se ve en la leyenda; el valor del factor sigue
        # siendo el nombre completo, así que data_id y tooltip no se alteran
        scale_fill_manual(values = mypalette, name = "Especies", drop = FALSE,
                          labels = abreviar_especie)
      } else {
        # drop = FALSE mantiene las dos entradas aunque un estado no tenga domesticadas,
        # para que la leyenda no cambie de forma al moverse entre estados
        scale_fill_manual(values = colores_condicion, name = "Condición", drop = FALSE)
      }

      dos <- ggplot(celdas, aes(x = columna, y = fila)) +
        geom_tile_interactive(
          aes(fill = relleno, data_id = Especie, tooltip = tip),
          colour = "white", linewidth = 0.8, width = 0.9, height = 0.9) +
        capa_multicolor +
        escala_relleno +
        coord_equal() +
        labs(title = "Proporción de especies de frijol",
             subtitle = "(Nota: Basado en el número de registros de cada especie por estado)",
             caption = nota_raras,
             x = NULL, y = NULL) +
        # nrow = 11 limita la leyenda a 11 renglones: si hay más especies (Michoacán,
        # Nayarit) se desbordan a una segunda columna en vez de crecer hacia abajo y
        # encimarse con la nota al pie. Con pocas especies queda una sola columna.
        guides(fill = guide_legend(nrow = 11,
                                   title.theme = element_text(size = 20))) +
        theme_minimal() +
        # la cursiva es la convención para nombres científicos, así que solo aplica
        # cuando la leyenda lista especies
        theme(legend.text = element_text(size = 15,
                                         face = if (por_especie) "italic" else "plain"),
              legend.key.size = unit(0.9, "cm"),
              plot.title = element_text(size = 16, face = "bold"),
              plot.subtitle = element_text(color = "#525252"),
              plot.caption = element_text(color = "#525252", hjust = 0,
                                          size = 11, face = "italic"),
              plot.caption.position = "plot",
              panel.grid = element_blank(),
              axis.text = element_blank(),
              axis.ticks = element_blank())

      girafe(
        ggobj = dos,
        width_svg = 12,
        height_svg = 7,
        options = list(
          opts_hover(css = "stroke:#333333; stroke-width:2pt;"),
          opts_hover_inv(css = "opacity:0.30;"),
          opts_tooltip(css = "background-color:#333; color:#fff; padding:5px;
                              border-radius:4px; font-size:12px;"),
          # hidden = "selection" quita los dos botones de lazo, que no se usan.
          # Se conservan el zoom, la descarga en PNG y la pantalla completa.
          opts_toolbar(saveaspng = TRUE, pngname = "proporcion_por_estado",
                       hidden = "selection"),
          opts_sizing(rescale = TRUE)
        )
      )
    })
  
  } # end server
)
