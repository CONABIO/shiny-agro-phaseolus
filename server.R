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
    output$mymap1 <- renderLeaflet(
      {
        Tabla3 <- points()
        leaflet() %>%
          addProviderTiles(providers$CartoDB.Positron, group = "Mapa") %>%
          addProviderTiles(providers$Esri.WorldImagery, group = "Foto aérea") %>%
          addCircles(data = Tabla3, group = "Circles",
                     lng = ~Longitud, lat = ~Latitud,
                     color = Tabla3$RatingCol, weight = 5, opacity = 0.7,
                     popup = ~paste(sep = " ", "Especie:",Tabla3$Taxa,
                                    "<br/>", "Condición:",Tabla3$Habitat.1,
                                    "<br/>", "Estado:",Tabla3$Estado,
                                    "<br/>", "Municipio:",Tabla3$Municipio,
                                    "<br/>", "Localidad:",Tabla3$Localidad,
                                    "<br/>", "Altitud:",Tabla3$Altitud, "metros",
                                    "<br/>", "Año de colecta:", Tabla3$AnioColecta,
                                    "<br/>", "<br/>", "NA, ND, 9999 = no hay dato")) %>%
          addLayersControl(
            baseGroups = c("Mapa", "Foto aérea"),
            position = "topright",
            options = layersControlOptions(collapsed = FALSE))
      })
 
  #Para la Floración    
    observeEvent(
      input$Estado1,
        updateSelectInput(session, inputId = "Especie1", label = "Especie:", 
                          choice = c("All" ,levels(droplevels(Mex4$Especie[Mex4$Estado %in% input$Estado1])))))
    
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
  max(600, length(unique(FloFru1_data()$Especie)) * 28)
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
      d <- Mex4[Mex4$Estado %in% input$Estado_alt, ]
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
      # Etiqueta abreviada: "Phaseolus vulgaris" -> "P. vulgaris"
      L$etiqueta <- sub("^Phaseolus\\s+", "P. ", as.character(L$Especie))
      L
    })

    DESPEGUE <- 200  # metros que el nombre se levanta sobre su propio valor

    # Alto de la gráfica: ~15 px por especie es lo que necesita un renglón de texto
    alto_graph2 <- reactive({
      LL <- Mex10()
      if (nrow(LL) == 0) return(600)
      max(650, nrow(LL) * 15 + 130)
    })

    # Cada nombre va DESPEGUE metros encima de su propio punto, sin más ajustes.
    y_nombres <- function(LL, alto_px) LL$ordenar + DESPEGUE

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
      # La cresta pasa EXACTAMENTE por el valor de cada especie, sin suavizar, para
      # que cada punto quede posado sobre la superficie de la montaña.
      # (Antes se suavizaba con loess(span = 0.9), pero eso dejaba los puntos
      # flotando: 44 m de desviación promedio y hasta 168 m en el peor caso.)
      # Como las especies vienen ordenadas por `ordenar`, la ladera sube limpia sin
      # importar si se ordenó por promedio, máximo o mínimo.
      montana <- data.frame(x = c(0.3, LL$pos, n + 0.7),
                            y = c(0,   LL$ordenar, 0))

      LL$y_nombre <- y_nombres(LL, alto_graph2())
      techo <- max(LL$y_nombre) + DESPEGUE

      # Los nombres se alternan: uno sale hacia la izquierda de su punto y el
      # siguiente hacia la derecha. Como los que se encinan son siempre vecinos,
      # al mandarlos a lados opuestos dejan de estorbarse.
      LL$lado     <- ifelse(LL$pos %% 2 == 1, -1, 1)
      LL$x_nombre <- LL$pos + LL$lado * 0.15
      LL$h        <- ifelse(LL$lado < 0, 1, 0)   # 1 = termina en el punto, 0 = arranca

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
        geom_polygon(data = montana, aes(x, y), fill = "#EFE0C4", colour = NA) +
        capa_capitales +
        # línea punteada que une el punto con su nombre
        geom_segment_interactive(
          data = LL,
          aes(x = pos, xend = pos, y = ordenar, yend = y_nombre, data_id = Especie),
          colour = "grey45", linewidth = 0.4, linetype = "dashed") +
        geom_point_interactive(
          data = LL,
          aes(x = pos, y = ordenar, data_id = Especie,
              tooltip = paste0(Especie, "\n", round(ordenar), " m")),
          colour = "grey20", size = 1.8) +
        geom_text_interactive(
          data = LL,
          aes(x = x_nombre, y = y_nombre, label = etiqueta, hjust = h,
              data_id = Especie,
              tooltip = paste0(Especie, "\n", round(ordenar), " m")),
          size = 4, fontface = "italic", colour = "grey15") +
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
                               " de la especie"),
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
               paste(raras$Especie, collapse = ", "), ".")
      } else NULL

      dos <- ggplot(celdas, aes(x = columna, y = fila)) +
        geom_tile_interactive(
          aes(fill = Especie, data_id = Especie, tooltip = tip),
          colour = "white", linewidth = 0.8, width = 0.9, height = 0.9) +
        scale_fill_manual(values = mypalette, name = "Especies", drop = FALSE) +
        coord_equal() +
        labs(title = "Proporción de especies de frijol",
             subtitle = "(Nota: Basado en el número de registros de cada especie por estado)",
             caption = nota_raras,
             x = NULL, y = NULL) +
        guides(fill = guide_legend(title.theme = element_text(size = 20))) +
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
