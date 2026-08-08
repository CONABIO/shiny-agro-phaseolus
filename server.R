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
    output$mymap1 <- renderLeaflet({
      Tabla3 <- points()

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
        addProviderTiles(providers$CartoDB.Positron, group = "Mapa") %>%
        addProviderTiles(providers$Esri.WorldImagery, group = "Foto aérea") %>%
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
      #Epoca
      FloFru <- FloFru[FloFru$Epoca %in% input$Epoca,]
      #Tipo
      FloFru <- FloFru[FloFru$Tipo %in% input$Tipo,]
    })
    

FloFru1_data <- reactive({
  FloFru1 <- points1() %>%
    gather("Mes", "Val", 8:19) %>%
    rename("Categoria" = "NombreCategoriaTaxonomica") %>%
    rename("Genero1" = "Nombre_1_Nombre") %>%
    rename("Especie1" = "Nombre_Nombre") %>%
    group_by(Genero1, Especie1, Mes) %>%
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
  max(150, length(unique(FloFru1_data()$Especie)) * 28 + 70)
})

output$graph4 <- renderGirafe({

  FloFru1 <- FloFru1_data()

  # El título se arma con los filtros activos, ej.:
  # "Época de floración de los frijoles silvestres"
  titulo_graph4 <- paste0("Época de ", tolower(input$Epoca),
                          " de los frijoles ", tolower(input$Tipo))

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
    labs(title = titulo_graph4,
         x = NULL, y = NULL) +
    theme_minimal() +
    theme(panel.border = element_blank(),
          plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
          axis.text.y = element_text(size = 12, face = "italic"),
          axis.text.x = element_text(angle = 0, size = 12, hjust = 0.5, vjust = 0.5),
          legend.position = "")

  girafe(
    ggobj = p,
    width_svg = 12,
    height_svg = alto_graph4() / 72,
    options = list(
      opts_hover(css = "stroke:#333333; stroke-width:1.5pt;"),
      opts_hover_inv(css = "opacity:0.35;"),
      opts_tooltip(css = "background-color:#333; color:#fff; padding:5px;
                          border-radius:4px; font-size:12px;"),
      opts_toolbar(saveaspng = FALSE),
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
              data_id = Especie,
              tooltip = paste0(Especie, "\n", round(ordenar), " m")),
          nudge_x = LL$lado * 0.6,
          nudge_y = DESPEGUE,
          size = 4, fontface = "italic", colour = "grey15",
          segment.colour = "grey45", segment.linetype = "dashed",
          segment.size = 0.4,
          min.segment.length = 0,   # que siempre dibuje la línea guía
          box.padding = 0.3, point.padding = 0.2,
          max.overlaps = Inf,       # IMPRESCINDIBLE: si no, descarta nombres en silencio
          seed = 42) +              # para que el acomodo sea reproducible
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
                               "mínimo (tono oscuro), promedio y máximo (tono claro)"),
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
          opts_toolbar(saveaspng = FALSE),
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
      # waffle. En vez de desaparecerlas se dibujan aparte, en una fila propia
      # debajo de la rejilla, para no distorsionar las proporciones.
      TTabla1$Especie <- factor(TTabla1$Especie, levels = TTabla1$Especie)
      mypalette <- colores_waffle(input$paleta_waffle, nrow(TTabla1))

      comunes <- TTabla1[TTabla1$val1 > 0, ]
      raras   <- TTabla1[TTabla1$val1 == 0, ]

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

      # Fila aparte para las especies raras, separada de la rejilla por un hueco
      FILA_RARAS <- -2.2
      if (nrow(raras) > 0) {
        celdas_raras <- data.frame(
          Especie = raras$Especie,
          fila    = FILA_RARAS,
          columna = seq_len(nrow(raras)) - 1,
          tip     = paste0(raras$Especie, "\nmenos del 1% de los registros (",
                           sprintf("%.2f", raras$pct_real), "%)")
        )
        celdas <- rbind(celdas, celdas_raras)
      }

      # Nota al pie con los nombres de las especies que no alcanzan el 1%
      nota_raras <- if (nrow(raras) > 0) {
        paste0("Especies presentes que no alcanzan el 1% de los registros y por eso no ",
               "ocupan ningún cuadro (se muestran en la fila inferior):\n",
               paste(abreviar_especie(raras$Especie), collapse = ", "), ".")
      } else NULL

      dos <- ggplot(celdas, aes(x = columna, y = fila)) +
        geom_tile_interactive(
          aes(fill = Especie, data_id = Especie, tooltip = tip),
          colour = "white", linewidth = 0.8, width = 0.9, height = 0.9) +
        # labels solo abrevia lo que se ve en la leyenda; el valor del factor sigue
        # siendo el nombre completo, así que data_id y tooltip no se alteran
        scale_fill_manual(values = mypalette, name = "Especies", drop = FALSE,
                          labels = abreviar_especie) +
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
        theme(legend.text = element_text(size = 15, face = "italic"),
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
          opts_toolbar(saveaspng = FALSE),
          opts_sizing(rescale = TRUE)
        )
      )
    })
  
  } # end server
)
