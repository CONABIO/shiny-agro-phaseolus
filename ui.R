library(shiny)
library(shinydashboard)
library(shinydashboardPlus)
library(shinyjs)
library(tidyverse)
library(markdown)
library(leaflet)
library(plotly)
library(httr)
# library(rgdal)
library(tableHTML)
library(shinyWidgets)
library(ggiraph)


dashboardPage(
  skin = "yellow",
  
  ## Dashboard Header
  dashboardHeader(
    title = tagList(
      span(class = "logo-lg", img(src = "conabio_logo1.png", height = 35)),
      img(src = "CONABIO_LOGO_15_rojo.png", height = 35, align = "center")
    ),
    titleWidth = 200,
    fixed = TRUE,
    tags$li(
      class = "dropdown",
      tags$span(class = "navbar-frase", "Cada pueblo de México tiene su frijol")
    )
  ), # close dashboard header
  
  ## Sidebar Menu
  dashboardSidebar(
    width = 200,
    shinyjs::useShinyjs(),
    collapsed = F,
    disable = F,
    sidebarMenu(
      id = "navbar",
      #shinyjs::useShinyjs(),
      menuItem("Introducción", tabName = "home", icon = icon("home")),
      menuItem("Distribución", tabName = "widgets", icon = icon("map")),
      menuItem(
        "Altitud",
        tabName = "widgets1",
        icon = icon("certificate")
      ),
      menuItem(
        "Floración y fructificación",
        tabName = "widgets3",
        icon = icon("adjust")
      ),
      menuItem("Proporción de especies de frijol por estado", tabName = "widgets2", icon = icon("th"))
      # menuItem("Autores", tabName = "conabio", icon = icon("user")) # oculto temporalmente
    )
  ),
  # close sidebar menu
  
  ## Dashboard Body
  dashboardBody(
    tags$head(tags$link(rel = "stylesheet", type = "text/css", href = "styles.css")),

    ## Tab Items Pages
    tabItems(
      ## Home
      tabItem(
        tabName = "home",
        br(),
        br(),
        div(img(image = "Conabio_horizontal_rgb.png", width = "300"), style = "text-align: center;"),
        fluidRow(
          div(class = "contenido-frijol", includeMarkdownNewTab("extra_files/frijol_intro.md")),

          br(),
          h2(strong("Visualización:"), align = "center"),

          div(
            class = "visualizacion-cajas",
            fluidRow(
            box(
              title = strong("Distribución de los distinos frijoles en México"),
              closable = FALSE,
              width = 6,
              status = "warning",
              solidHeader = FALSE,
              collapsible = TRUE,
           #   h4(
           #     "Visualiza todos los registros de ",
           #     em("Phaseolus"),
           #     "con coordinadas
           #geográficas del proyecto. Los valores pueden filtrarse por las variables condición,
           #   estado y especie."
           #   ),
              userPostMedia(image = "MapDistribution1.png"),
              id = "mapa",
              style = "cursor:pointer;"
            ),

            box(
              title = strong("Rangos altitudinales donde crecen los distintos géneros de", em("Phaseolus")
              ),
              closable = FALSE,
              width = 6,
              status = "warning",
              solidHeader = FALSE,
              collapsible = TRUE,
            #  h4(
            #    "Rangos altitudinales donde crecen los distintos géneros de", em("Phaseolus")
            #  ),
              userPostMedia(image = "Altitud1.png"),
              id = "altitud",
              style = "cursor:pointer;"
            ),

            box(
              title = strong("Época de crecimiento y floración"),
              closable = FALSE,
              width = 6,
              status = "warning",
              solidHeader = FALSE,
              collapsible = TRUE,
              h4(
                "Cuándo crecen y florecen los frijoles"
              ),
              userPostMedia(image = "Crecimiento1.png"),
              id = "crecimiento",
              style = "cursor:pointer;"
            ),

            box(
              title = strong("Proporción de especies de frijol por estado"),
              closable = FALSE,
              width = 6,
              status = "warning",
              solidHeader = FALSE,
              collapsible = TRUE,
              #h4(
              #  "¿Cuál es la proporción de frijoles que hay en cada estado? Con
              #la gráfica de waffle se puede observar de forma rápida la proporción
              #de estos, ya que tiene 10 renglones x 10 columnas, es decir
              #100 cuadros que representan 100% de los registros de las especies
              #por cada estado"
              #),
              userPostMedia(image = "WafflePlot.png"),
              id = "waffle",
              style = "cursor:pointer;"
            )
            ) # close fluidRow
          ) # close div.visualizacion-cajas
#####
        ) #close fluidRow
      ), # close home tab
      
 #####     
      ## Para el mapa 1
      tabItem(
        tabName = "widgets",
        value = "distribucion_1",
        br(),
        fluidRow(
          tags$style("#mymap1 {height: calc(100vh - 10px) !important;}"),
          leafletOutput('mymap1')
        ),
        absolutePanel(
          id = "controls",
          top = 166,
          right = 10,
          width = 150,
          draggable = T,
          fixed = F,
          style = "z-index:100;",
          class = "panel-default",
          # Filtros cruzados (Condición, Estado, Especie) — shinyWidgets::selectizeGroupServer
          # se encarga de acotar las opciones de cada uno según los demás
          selectizeGroupUI(
            id = "my_filters",
            params = list(
              Habitat.1 = list(inputId = "Habitat.1", title = "Condición:"),
              Estado = list(inputId = "Estado", title = "Estado:"),
              Especie = list(inputId = "Especie", title = "Especie:")
            ),
            inline = FALSE
          ),

          # Botón de descarga de datos
          downloadButton("download_xlsx", "Descargar datos")

        ) # close absolute panel
      ), # close tabItem widget page
#####
      ## Para la gráfica de la Altitud
      tabItem(
        tabName = "widgets1",
        br(),
        br(),
        fluidRow(
          column(
            width = 3,
            # Filtro de estados — permite elegir uno o varios
            pickerInput(
              inputId = 'Estado_alt',
              label = h6(strong('Estado:')),
              choices = levels(Mex4$Estado),
              selected = levels(Mex4$Estado),
              multiple = TRUE,
              options = pickerOptions(
                actionsBox = TRUE,
                liveSearch = TRUE,
                selectedTextFormat = "count > 2",
                countSelectedText = "{0} estados seleccionados",
                noneSelectedText = "Ningún estado seleccionado",
                selectAllText = "Todos",
                deselectAllText = "Ninguno",
                liveSearchPlaceholder = "Buscar estado..."
              ),
              width = 200
            ),
            #Seleccionar la variable para
            selectInput(
              inputId = 'var11',
              label = h6(strong('Ordenar por:')),
              choices = c("promedio", "máximo", "mínimo"),
              width = 200
            ),
            # Líneas de referencia: altitud de las capitales estatales, para que
            # la gente ubique su ciudad y vea qué frijoles crecen a esa altura
            pickerInput(
              inputId = 'capitales',
              label = h6(strong('Comparar con la altitud de:')),
              choices = capitales_opciones,
              selected = character(0),
              multiple = TRUE,
              options = pickerOptions(
                liveSearch = TRUE,
                selectedTextFormat = "count > 1",
                countSelectedText = "{0} ciudades",
                noneSelectedText = "Ninguna ciudad",
                liveSearchPlaceholder = "Buscar ciudad..."
              ),
              width = 200
            )
          ),
          column(
            width = 9,
            # height = "auto": el contenedor toma la altura de la imagen, que
            # renderPlot calcula según el número de especies (ver alto_graph2)
            # gráfica interactiva (ggiraph): al pasar el mouse por una especie se
            # resaltan su punto, su línea punteada y su nombre a la vez
            girafeOutput('graph2', height = "auto", width = "100%")
          )
        )
      ), # close widget page

      ## Para la gráfica de la Temporada de lluvias
      tabItem(
        tabName = "widgets3",
        br(),
        br(),
        fluidRow(
          column(
            width = 3,
            #Seleccionar la variable para Epoca
            selectInput(
              inputId = 'Epoca',
              label = h6(strong('Época:')),
              choices = levels(FloFru$Epoca),
              selected = "Floración",
              width = 200
            ),
            #Seleccionar la variable para Tipo
            selectInput(
              inputId = 'Tipo',
              label = h6(strong('Tipo:')),
              choices = levels(FloFru$Tipo),
              selected = "Silvestres",
              width = 200
            ),
            # Color de la gráfica — paleta FantasticFox1 (wesanderson).
            # Cada opción se muestra con su propio color de fondo.
            pickerInput(
              inputId = 'color_fox',
              label = h6(strong('Color:')),
              choices = names(paleta_fox),
              selected = "Azul",
              choicesOpt = list(
                style = paste0("background-color:", unname(paleta_fox),
                               "; color: white; font-weight: bold;")
              ),
              width = 200
            )
          ),
          column(
            width = 9,
            # interactiva: al pasar el mouse por un mes se resalta toda la especie
            girafeOutput('graph4', height = "auto", width = "100%")
          )
        )
      ), # close widget3 page

      ## Para el waffle
      tabItem(
        tabName = "widgets2",
        br(),
        br(),
        fluidRow(
          column(
            width = 3,
            selectInput(
              inputId = "Estado2",
              label = h6(strong("Estado:")),
              choices = c(levels(Mex3$Estado)),
              selected = c("Oaxaca"),
              width = 200
            ),
            # Paleta de colores: cada opción encadena varias paletas de wesanderson
            # para tener suficientes matices distintos (ver combos_waffle en global.R)
            selectInput(
              inputId = "paleta_waffle",
              label = h6(strong("Paleta de colores:")),
              choices = nombres_combos,
              selected = nombres_combos[1],
              width = 200
            )
          ),
          column(
            width = 9,
            # interactiva: al pasar el mouse por un cuadro se resalta toda la especie
            girafeOutput('graph3', height = "auto", width = "100%")
          )
        )
      ), # close  tabItem

#####    
      # About Page
      tabItem(
        tabName = "conabio",
        br(),
        fluidRow(
          column(
            width = 12,
            h3(strong("Autores:"), align = "center")
          )
        ),
        fluidRow(
          column(
            width = 4,
            userBox(
              title = userDescription(
                title = "Dr. Alfonso Octavio Delgado Salinas",
                subtitle = "Responsable del Proyecto",
                type = 2,
                image = "Catbus.png",  # Asegúrate que esté en carpeta `www/`
              ),
              width = 12,  # Este 'width' es interno a la caja
              background = "blue",
              "Some text here",
              footer = "UNAM",
              collapsed = TRUE
            )
          ),
          column(
            width = 4,
            userBox(
              title = userDescription(
                title = "M. en C. Susana Gama López",
                subtitle = "Técnico Externo",
                type = 2,
                image = "Catbus.png",  # Asegúrate que esté en carpeta `www/`
              ),
              width = 12,  # Este 'width' es interno a la caja
              background = "blue",
              "Some text here",
              footer = "UNAM",
              collapsed = TRUE
            )
          ),
          column(
            width = 4,
            userBox(
              title = userDescription(
                title = "Dr. Enrique Martínez-Meyer",
                subtitle = "Co-responsables del Proyecto",
                type = 2,
                image = "Catbus.png",  # Asegúrate que esté en carpeta `www/`
              ),
              width = 12,  # Este 'width' es interno a la caja
              background = "blue",
              "Some text here",
              footer = "UNAM",
              collapsed = TRUE
            )
          ),
          column(
            width = 4,
            userBox(
              title = userDescription(
                title = "Dr. Jorge Alberto Acosta Gallegos",
                subtitle = "Colaborador Externo",
                type = 2,
                image = "Catbus.png",  # Asegúrate que esté en carpeta `www/`
              ),
              width = 12,  # Este 'width' es interno a la caja
              background = "blue",
              "Some text here",
              footer = "Institution",
              collapsed = TRUE
            )
          )
        ),
        br(),
        fluidRow(
          column(
            width = 12,
            h3(strong("CONABIO:"), align = "center")
          )
        ),
        fluidRow(
          column(
            width = 4,
            userBox(
              title = userDescription(
                title = "Oswaldo Oliveros Galindo",
                subtitle = "Especialista en Agrobiodiversidad",
                type = 2,
                image = "Catbus.png",  # Asegúrate que esté en carpeta `www/`
              ),
              width = 12,  # Este 'width' es interno a la caja
              background = "yellow",
              "Some text here",
              footer = a(href = "http://www.conabio.gob.mx/web/conocenos/CGAyRB_CA.html", "Conabio"),
              collapsed = TRUE
            )
          ),
          column(
            width = 4,
            userBox(
              title = userDescription(
                title = "Alejandro Ponce-Mendoza",
                subtitle = "Experto para el Análisis de Información de Agrobiodiversidad",
                type = 2,
                image = "APM.jpg",  # Asegúrate que esté en carpeta `www/`
              ),
              width = 12,  # Este 'width' es interno a la caja
              background = "yellow",
              "Trabajo en la",
              tags$a(href = "http://www.conabio.gob.mx/web/conocenos/CGAyRB_CPAM.html", target = "_blank", rel = "noopener noreferrer", "Conabio"),
              "para conservación de la agrobiodiversidad. Me interesa la visualización y análisis,
                                 de datos ecológicos. Mis publicaciones las puedes encontrar",
              tags$a(href = "https://scholar.google.com/citations?user=M1i6_loAAAAJ&hl=en", target = "_blank", rel = "noopener noreferrer", "aquí"),".",
              footer = p(tags$a(href = "http://www.conabio.gob.mx/web/conocenos/CGAyRB_CPAM.html", target = "_blank", rel = "noopener noreferrer", "Conabio"),
                         tags$a(href = "https://github.com/APonce73", target = "_blank", rel = "noopener noreferrer", "Github")),
              collapsed = TRUE
            )
          )
        ) # clore FluidRow
      ) # close tabItem about page
#####        
      
    ) # close tabItems
  ) # close body
) # end UI