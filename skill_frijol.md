# Bitácora — Proyecto shiny-agro-phaseolus (frijol)

Documentación de avances y decisiones del trabajo en el repo
[CONABIO/shiny-agro-phaseolus](https://github.com/CONABIO/shiny-agro-phaseolus).

## 📋 Checklist reutilizable — clonar y levantar cualquier Shiny desde GitHub

*(Copia y pega esta sección en el próximo proyecto. Genérica, sin nada específico de frijol.)*

**1. Clonar el repo**
```bash
git clone <url-del-repo> <carpeta-destino>
```
No hace falta `git init` — `git clone` ya inicializa el repo. Si la carpeta destino
no está vacía (por ejemplo trae una `.claude/` u otra carpeta oculta), clona a una
carpeta temporal y mueve el contenido (incluyendo `.git`) a la carpeta final.

**2. Revisar permisos de escritura en GitHub**
```bash
gh api repos/<org>/<repo> --jq '.permissions'
```
- `push: false` → solo lectura. Puedes seguir trabajando en local (clonar, editar,
  commits locales) sin problema; el permiso solo hace falta al momento de `git push`.
- Si te falta acceso, pide que te agreguen como colaborador (a un admin o contribuidor
  visible del repo) — vía correo o Issue en el repo.

**3. Crear una rama de trabajo — nunca tocar `main` directo**
```bash
git checkout -b nombre-descriptivo-del-cambio
```
Trabajas y haces commits ahí; al final se abre un Pull Request hacia `main`.
Cambiar de rama no duplica archivos — solo actualiza el contenido de la carpeta
para reflejar esa rama (el historial completo vive comprimido en `.git/`).

**4. Revisar si el proyecto usa renv (`renv.lock` en la raíz)**
- Si existe `renv.lock` pero no hay carpeta `renv/` ni `.Rprofile` (normal, van en
  `.gitignore`), renv no se activa solo — hay que restaurarlo:
  ```r
  install.packages("renv")
  renv::restore()
  ```
- Si pregunta por activar el proyecto (`1: Activate...`), elegir **opción 1**
  (librería aislada solo para ese proyecto, no toca la librería global de R).
- La activación puede pedir reiniciar la sesión (**Session → Restart R**) — **hay que
  volver a correr `renv::restore()` después del restart**, el reinicio interrumpe el
  proceso.
- Revisa la versión de R que pide el lockfile:
  ```bash
  grep -A2 '"R":' renv.lock
  ```
  Si tu R local no coincide (sobre todo si es **más vieja**), vas a tener errores de
  paquetes que requieren una versión mínima. Instala la versión exacta del lockfile
  desde [cran.r-project.org/bin/macosx](https://cran.r-project.org/bin/macosx/) —
  coincidir versión evita que renv tenga que compilar paquetes desde código fuente
  (compilar desde source en Mac puede fallar por incompatibilidades del compilador).
- En Mac, si tienes varias versiones de R instaladas y RStudio no te deja elegir en
  **Tools → Global Options → General**, lánzalo apuntando a la versión correcta:
  ```bash
  ls /Library/Frameworks/R.framework/Versions/   # ver qué versiones hay instaladas
  open -a RStudio --env RSTUDIO_WHICH_R=/Library/Frameworks/R.framework/Versions/<version>/Resources/bin/R
  ```
  Verifica con `R.version.string` en la consola que tomó la versión correcta.

**5. Si un paquete no compila o "no está disponible"**
- Error de compilación en Mac (código C/C++ que ya no compila contra librerías del
  sistema actualizadas): prueba instalar una versión más nueva del paquete —
  `renv::install("paquete")` sin versión fija — antes de pelear con el compilador.
- `Error: package 'X' is not available`: puede estar **archivado de CRAN**. Búscalo en
  [cran.r-project.org/package=X](https://cran.r-project.org) — si dice "Archived",
  busca un fork activo en GitHub e instala con `renv::install("usuario/repo")`.
- `renv::install()` con una **lista** de paquetes aborta TODO el lote si uno solo
  falla en la fase de resolución (aunque el log muestre "Downloading ... OK" para los
  demás — esa fase es solo descarga, no instalación). Si falla, hay que volver a
  correr el resto de la lista una vez resuelto el paquete problemático.
- Si `renv::install("usuario/repo")` falla con un error de red al llamar a la API de
  GitHub (`error code 56` u otro), y `git clone` normal sí te funciona: clona el repo
  a mano y instala desde ahí — `renv::install("/ruta/local/al/repo")`. Pero luego
  **reintenta el `renv::install("usuario/repo")` normal** antes de hacer snapshot final,
  para que el lockfile quede con la fuente de GitHub y no con una ruta local que solo
  existe en tu máquina (si el error era pasajero, la segunda vez sí funciona).
- Después de instalar/actualizar un paquete que ya estaba cargado en la sesión activa
  (error tipo "namespace ya está cargado pero se requiere versión >= X"): reinicia la
  sesión (**Session → Restart R**), no basta con haberlo instalado en disco.

**6. Correr la app**
```r
shiny::runApp()
```

**7. Guardar el entorno que sí funciona**
```r
renv::snapshot()
```
Actualiza `renv.lock` para reflejar las versiones reales instaladas — importante si te
desviaste del lockfile original por paquetes rotos/archivados.

---

## Contexto del proyecto

Alex (usuario) desarrolló originalmente esta app Shiny y la publicó en shinyapps.io.
Después dejó la empresa/proyecto, y en algún momento posterior CONABIO hizo el deploy
en sus propios servidores — ese trabajo de empaquetado para producción (renv.lock,
Dockerfile, docker-compose.yml) lo hizo alguien más, no Alex. Por eso el código de la
app (`global.R`, `ui.R`, `server.R`) es familiar, pero el setup de dependencias/deploy
es nuevo para él.

Su cuenta de GitHub sigue activa dentro de la organización CONABIO (nunca lo dieron de
baja — práctica común para que devs puedan cerrar pendientes), por eso pudo clonar el
repo sin fricción. El permiso de escritura faltante (`push: false`) es específico de
**este repo** — nunca lo agregaron como colaborador directo aquí, independientemente
de su membresía en la organización.

## Setup inicial

- Directorio de trabajo: `/Users/alex_ponce/Dropbox/JANO/2026/shiny_frijol`
- Repo clonado directo desde GitHub (no se hizo `git init` manual — `git clone` ya inicializa el repo).
- Usuario GitHub: `APonce73`

## Estructura del repo

- `global.R`, `ui.R`, `server.R` — app Shiny principal
- `data/`, `www/`, `extra_files/`, `scripts/`
- `renv.lock` — dependencias con versiones fijas (renv)
- `Dockerfile`, `docker-compose.yml`
- `conabio_frijol.Rproj`

## Permisos en GitHub

- Verificación de permisos con:
  ```bash
  gh api repos/CONABIO/shiny-agro-phaseolus --jq '.permissions'
  ```
- Estado inicial: `pull: true`, `push: false` → sin acceso de escritura.
- Se envió correo solicitando acceso de colaborador a los contribuidores del repo
  (`stkaren92`, `jmbarrios`), pendiente de confirmación.
- Mientras no haya `push: true`, se puede seguir trabajando localmente sin problema
  (clonar, editar, hacer commits locales) — el permiso solo se necesita al momento de
  hacer `git push`.

## Flujo de trabajo con Git (branches)

- **No se debe modificar `main` directamente.** Se trabaja en una rama nueva y luego
  se abre un Pull Request.
- Rama de trabajo creada: **`frijol-cambios`**
- Comandos clave:
  ```bash
  git checkout -b frijol-cambios   # crear y cambiar a la rama
  git checkout main                # volver a main
  git checkout frijol-cambios      # volver a la rama de trabajo
  git branch                       # ver rama activa (marcada con *)
  ```
- Concepto: las ramas **no duplican archivos** en la carpeta. Solo existe una copia de
  los archivos en disco a la vez; el historial completo vive comprimido en `.git/`.
  Cambiar de rama actualiza el contenido de la carpeta para reflejar esa rama
  (analogía: separadores de páginas en el mismo libro, no libros distintos).
- Abrir el proyecto en RStudio (`conabio_frijol.Rproj`) siempre refleja la rama activa
  en ese momento — los cambios y commits se guardan en la rama en la que estés parado.

## Manejo de dependencias (renv)

- El repo incluye `renv.lock` pero **no** la carpeta `renv/` ni `.Rprofile`
  (están en `.gitignore` — es lo normal, no se versiona la librería instalada).
- Esto significa que en un clon nuevo, renv no se activa automáticamente.
- Error inicial al correr la app: `there is no package called 'waffle'`
  (y luego `tidyverse` también faltante) — paquetes no instalados en la máquina local.
- Solución (en vez de instalar paquetes uno por uno, que podría traer versiones
  distintas a las que usó el desarrollador original):
  ```r
  install.packages("renv")
  renv::restore()
  ```
- Al correr `renv::restore()` por primera vez en un proyecto no activado, pregunta:
  ```
  1: Activate the project and use the project library.
  2: Do not activate the project and use the current library paths.
  3: Cancel and resolve the situation another way.
  ```
  → Se eligió **opción 1** (activar el proyecto, librería aislada solo para este
  proyecto, no afecta la librería global de R ni otros proyectos).
- La activación pidió reiniciar la sesión de R (**Session → Restart R**). Importante:
  el restart interrumpe el proceso de restauración — hay que **volver a correr
  `renv::restore()` después de reiniciar** para que efectivamente instale los
  paquetes del lockfile.
- Por qué versiones fijas y no las últimas: reproducibilidad. La app se desarrolló y
  probó con versiones específicas; actualizar sin control puede romper funciones por
  cambios de sintaxis entre versiones (breaking changes), generando errores difíciles
  de diagnosticar. Es como un `node_modules` por proyecto: aislado y reproducible.
### Problemas encontrados durante `renv::restore()` (Mac Intel)

En la práctica, `renv::restore()` con el lockfile original **no terminó de funcionar**
tal cual — varios paquetes con componentes C/C++ ya no compilan contra las versiones
actuales de librerías del sistema, y algunos paquetes de CRAN fueron archivados desde
que se generó el lockfile. Bitácora de cada bloqueo y su solución:

1. **`Matrix` no compila** — requería R >= 4.4, pero R local era 4.3.3.
   → Se instaló R 4.5-x86_64 (versión exacta del lockfile) desde CRAN, sin desinstalar
   las versiones previas (Mac permite varias versiones de R en paralelo).
   → Como RStudio no mostraba el selector de versión en Options, se lanzó apuntando a
   la versión correcta desde Terminal:
   ```bash
   open -a RStudio --env RSTUDIO_WHICH_R=/Library/Frameworks/R.framework/Versions/4.5-x86_64/Resources/bin/R
   ```

2. **`terra` no compila contra GDAL** — error `assigning to 'char **' from
   'CSLConstList'`. La versión fija en el lockfile (`1.8-54`) es incompatible con GDAL
   moderno (>= 3.13, instalado vía Homebrew). CRAN ya no publica binarios de macOS
   Intel para paquetes recientes, así que siempre intenta compilar desde código fuente
   en este tipo de Mac.
   → Solución: instalar una versión más nueva de `terra` que sí sea compatible:
   ```r
   renv::install("terra")   # instaló 1.9-34, sí compila
   ```

3. **Conflictos de librerías de Homebrew en cascada** (`jpeg-xl`, luego `abseil`/`re2`)
   al intentar compilar `terra`/GDAL — típico de fórmulas de Homebrew desincronizadas
   entre sí.
   → Solución: `brew update && brew upgrade` (en vez de arreglar una por una).

4. **`textshaping` no compila** — faltaban librerías de sistema `harfbuzz` y `fribidi`.
   → `brew install harfbuzz fribidi`

5. **`ggalt` "not available"** — el paquete fue **archivado de CRAN el 2025-08-02**.
   → Se instaló desde el fork activo en GitHub:
   ```r
   renv::install("yonicd/ggalt")
   ```

6. **`waffle` "not available"** — archivado de CRAN el 2025-09-09 por depender de
   `extrafont`, que también estaba archivado (aunque luego fue restaurado a CRAN el
   2025-09-24 bajo nuevo mantenedor).
   → `renv::install("extrafont")` funcionó directo desde CRAN.
   → `renv::install("hrbrmstr/waffle")` (el paquete original en GitHub) falló con
   `error code 56` (error de red al llamar a la API de GitHub, causa no clara — no era
   falta de internet). Se resolvió clonando el repo por git normal (que sí funcionaba)
   e instalando desde la copia local:
   ```bash
   git clone https://github.com/hrbrmstr/waffle.git /tmp/waffle_pkg
   ```
   ```r
   renv::install("/tmp/waffle_pkg")
   ```

7. **`renv::install()` con una lista de paquetes aborta todo el lote si UNO falla en
   la fase de resolución** — no instala los que sí estaban disponibles. Pasó dos veces
   (con `colorspace`+`ggalt`, y con `ggmap`+...+`waffle`): al fallar el último paquete
   de la lista, ninguno de la lista se instaló realmente, aunque el log mostrara
   "Downloading ... OK" para los demás (esa fase es solo resolución, no instalación).
   → Lección: si un lote falla, hay que re-intentar el resto de la lista explícitamente
   una vez resuelto el paquete problemático — no basta con arreglar solo ese uno.

8. **Choques de versión en la sesión de R viva** (ej. `shiny` requería
   `promises >= 1.5.0` pero R ya tenía cargada la `1.3.2` vieja en memoria) — instalar
   la versión nueva en disco no basta si la vieja ya está cargada en la sesión activa.
   → Solución: **Session → Restart R** después de instalar/actualizar un paquete que
   ya se había cargado antes en la misma sesión.

**Resultado final:** la app corre con `runApp()`. Se corrió `renv::snapshot()` y el
`renv.lock` quedó actualizado y sincronizado con el entorno real que funciona.

Detalle importante post-snapshot: la primera vez, `waffle` quedó registrado como
fuente **"Local"** (apuntando a `/tmp/waffle_pkg`, la carpeta temporal usada para
sortear el `error code 56` de la API de GitHub) — esto habría roto `renv::restore()`
para cualquier otra persona, ya que esa ruta solo existe en esta máquina. Se corrigió
reintentando `renv::install("hrbrmstr/waffle")` (el error de red anterior resultó ser
pasajero) y volviendo a correr `renv::snapshot()` — ahora `waffle` queda registrado
correctamente como fuente de GitHub (`hrbrmstr/waffle`), reproducible para cualquiera.

## Cambios hechos en la app (rama `frijol-cambios`)

1. **Ocultar pestaña "Autores"** — [ui.R:46](ui.R#L46)
   Se comentó el `menuItem("Autores", tabName = "conabio", ...)` del sidebar. El
   contenido de esa pestaña (`tabItem(tabName = "conabio", ...)`) sigue en el código,
   solo quedó inalcanzable desde el menú — fácil de reactivar descomentando esa línea.

2. **Nueva introducción** — [extra_files/frijol_intro.md](extra_files/frijol_intro.md)
   Texto nuevo de introducción sobre el frijol en México, provisto por el usuario.
   - Se quitó del archivo una sección final ("Nota de estilo") que era una instrucción
     para el desarrollo, no contenido para mostrar en la app.
   - En [ui.R](ui.R) se reemplazó todo el bloque viejo de "Introducción" (los dos
     `h4()` largos sobre taxonomía de *Phaseolus*) por una llamada a
     `includeMarkdownNewTab("extra_files/frijol_intro.md")`, envuelta en
     `div(class = "contenido-frijol", ...)`.
   - También se quitó el encabezado viejo `h2("Proyecto: El género Phaseolus...")`
     que quedaba arriba, ya que el nuevo markdown trae su propio título.
   - La sección **"Visualización"** y todo lo que sigue (recuadros de Distribución,
     Altitud, etc.) se dejó intacto, tal como pidió el usuario.

3. **Estilos nuevos para el texto** — [www/styles.css](www/styles.css)
   Tipografía PT Sans/Oswald, interlineado 1.5, ligas en color café/ocre — provisto
   por el usuario para que la introducción luzca similar a la página de CONABIO.
   - Se conectó en [ui.R:53](ui.R#L53) vía `tags$head(tags$link(..., href = "styles.css"))`
     (antes estaba comentado y además apuntaba a un nombre de archivo distinto,
     `style.css`, que no existía).
   - **Bug detectado y corregido:** las reglas originales aplicaban a `h1`-`h4`
     de **toda la página**, no solo a la introducción — esto agrandó el texto de los
     recuadros de "Visualización" (que también usan `h4()` para sus descripciones).
     Se acotaron todas las reglas de tipografía bajo el selector `.contenido-frijol`
     para que solo afecten al bloque de introducción.

4. **Ligas abren en pestaña nueva del navegador**
   Petición del usuario: que ninguna liga navegue fuera de la Shiny en la misma pestaña.
   - Se agregó `includeMarkdownNewTab()` en [global.R](global.R) — convierte el
     markdown a HTML con `markdown::markdownToHTML()` y luego usa `gsub()` para
     inyectar `target="_blank" rel="noopener noreferrer"` en cada `<a href=`.
   - Se usa esa función (en vez de `includeMarkdown()` de toda la vida) para renderizar
     `frijol_intro.md`.
   - Se agregó `target="_blank" rel="noopener noreferrer"` manualmente a las 3 ligas
     que ya existían en `tags$a()` dentro de la pestaña de Autores (Conabio, Google
     Scholar, GitHub) — por consistencia, aunque esa pestaña esté oculta por ahora.

5. **Cajas de "Visualización" de distinto tamaño** — [ui.R](ui.R),
   [www/styles.css](www/styles.css)
   Las 4 cajas (Distribución, Altitud, Época, Proporción por estado) se veían de
   alturas distintas porque `box()` ajusta su alto al contenido, y cada una tiene
   texto/imagen de tamaño diferente.
   - Se envolvió la fila de cajas en `div(class = "visualizacion-cajas", fluidRow(...))`.
   - En `styles.css` se agregaron reglas flexbox (`.visualizacion-cajas .row`,
     `.box`, `.box-body`) para que las 4 cajas se estiren a la misma altura, y se fijó
     el alto de las imágenes a `200px` con `object-fit: cover` para que no varíen según
     el tamaño original de cada imagen.

6. **Nombre de la gráfica de waffle** — decidido con el usuario: se renombró de
   "Gráfica de Waffle"/"Gráfica de waffle" a **"Proporción de especies de frijol por
   estado"**, tanto en el `menuItem` del sidebar como en el `title` de la caja
   correspondiente — más descriptivo que el nombre técnico del tipo de gráfica.

7. **Selectores encimados sobre las gráficas** (pestañas Altitud y Floración y
   fructificación) — el patrón `absolutePanel(top=.., right=..)` posiciona el control
   de forma flotante y fija sobre la gráfica, sin importar el contenido de esta, lo
   que causaba que el selector tapara partes de la figura.
   → Se reemplazó `absolutePanel` por un layout de columnas normal
   (`fluidRow(column(width=3, selectInput(...)), column(width=9, plotOutput(...)))`)
   en ambas pestañas (`widgets1` y `widgets3`) — el selector queda en su propia columna
   a la izquierda, nunca se puede encimar con la gráfica sin importar su tamaño.
   La pestaña de Distribución (`widgets`) se dejó igual porque ya usa
   `absolutePanel(draggable = TRUE)`, que es una solución distinta (el usuario puede
   arrastrar el panel si le estorba) y no fue reportada como problema.

8. **Consistencia visual entre pestañas de gráficas** — se rehizo también la pestaña
   de "Proporción de especies de frijol por estado" (`widgets2`) con el mismo patrón
   de columnas (antes usaba `absolutePanel`). Además se agregó un `br()` extra al
   inicio de la pestaña de Altitud (`widgets1`) para que su selector quede a la misma
   altura vertical que en Floración y fructificación (`widgets3`) y en la del waffle —
   antes se veía más arriba por tener un `br()` menos antes del `fluidRow`.

9. **Renglones amontonados en las gráficas de Altitud (`graph2`) y Floración
   (`graph4`)** — [server.R](server.R), [ui.R](ui.R)
   Causa: la altura del contenedor estaba fija (`calc(100vh - 80px)`) sin importar
   cuántas categorías (especies) tuviera el eje Y — con ~60 especies en Altitud, cada
   renglón terminaba con apenas ~12-15px de alto.
   - En `server.R`, ambos `renderPlot()` ahora reciben un argumento
     `height = function() max(600, n_categorias * 28)` — la altura real de la imagen
     generada crece según el número de categorías (mínimo 600px), en vez de quedar fija
     al alto de pantalla.
   - Se extrajo el cálculo de `FloFru1` (antes solo vivía dentro del `renderPlot` de
     `graph4`) a una `reactive()` separada (`FloFru1_data`), para poder reusar el
     conteo de especies tanto en el plot como en el cálculo de altura sin duplicar
     lógica.
   - En `ui.R`, se quitó el CSS que forzaba la altura del `plotOutput` a la de la
     pantalla (`!important`).
   - Primer intento: envolver cada `plotOutput` en un
     `div(style = "max-height: calc(100vh - 80px); overflow-y: auto;")` para permitir
     scroll interno si la gráfica crecía más que la pantalla. **Descartado** — el
     usuario prefirió que la gráfica se vea completa siempre, sin recorte ni scroll
     escondido dentro de un cuadro (riesgo de que la gente piense que no hay más datos
     abajo). Se quitó ese `div` envolvente: ahora el `plotOutput` se muestra a su
     altura completa (la que calcula `renderPlot`) y es la página entera la que crece
     y se desplaza con el scroll normal del navegador — más evidente que hay más
     contenido abajo.

## Nota sobre ediciones simultáneas

Varias veces el usuario editó `ui.R` directamente en RStudio mientras yo también lo
editaba. Cuando eso pasa, el último guardado gana y puede revertir sin querer cambios
del otro. Ya pasó una vez con el renombre de "Waffle" — se resolvió reaplicando el
cambio sobre la versión más reciente del archivo. **Recomendación:** si el usuario va a
editar el archivo a mano, guardar esos cambios antes de pedir un cambio nuevo, para no
pisarnos el trabajo.

## Próximos pasos

- [x] Confirmar que la app corre localmente (`shiny::runApp()`)
- [x] Correr `renv::snapshot()` para actualizar el lockfile con el entorno que sí funciona
- [x] Ocultar pestaña de Autores
- [x] Reemplazar introducción con el nuevo texto y estilos
- [x] Hacer que las ligas abran en pestaña nueva
- [x] Igualar el tamaño de las cajas de Visualización
- [x] Renombrar la gráfica de waffle
- [x] Corregir selectores encimados sobre las gráficas (Altitud, Floración, Waffle)
- [x] Dar más espacio entre renglones en las gráficas de Altitud y Floración
- [x] Mostrar la gráfica completa siempre (sin recorte ni scroll interno)
- [x] Insertar imagen `cartel_frijoles.png` centrada en la introducción
      (el `<div>` que la envuelve lleva `margin: 2rem 0 2.75rem` — sin eso el párrafo
      siguiente queda pegado a la imagen, porque el margen del `<p>` no se aplica
      contra un `<div>` hermano)
- [x] Reemplazar el texto "Frijol" del cintillo superior por el logo de CONABIO
- [x] Centrar la frase "Cada pueblo de México tiene su frijol" en el cintillo
      superior. Historial de intentos:
      1. `position: absolute` con `left: 200px` dentro de `.main-header` — quedó
         pegado arriba a la derecha (el `<nav>` interno ya trae
         `margin-left: 200px` por el `titleWidth` de
         `shinydashboard::dashboardHeader()`, el offset manual sobraba).
      2. `left: 0; right: 0` dentro de `.main-header .navbar { position: relative; }`
         — con font-size 36.8px el texto se desbordó fuera de la pantalla, señal de
         que `.navbar` no tenía el ancho esperado (floats internos de AdminLTE o
         especificidad CSS de Bootstrap ganándole a la regla).
      3. **Solución que funcionó:** `position: fixed` (relativo a la ventana del
         navegador, no a un ancestro dentro del header) con
         `left: 200px; right: 0; height: 50px;` — evita depender por completo de la
         estructura/anchos internos de AdminLTE. Confirmado visualmente con captura
         de pantalla en sesión de pruebas: quedó centrada y en una sola línea a
         36.8px (Oswald 600, igual al `h1` de la introducción).
- [x] Logo distinto cuando se minimiza el sidebar — patrón ya usado por el usuario en
  otro proyecto CONABIO: `title` del `dashboardHeader` es un `tagList()` con dos
  imágenes — la de sidebar expandido envuelta en `span(class = "logo-lg", ...)`
  (`conabio_logo1.png`) y una segunda sin envolver que AdminLTE muestra cuando el
  sidebar está colapsado (`CONABIO_LOGO_15.png`, ya provista por el usuario en `www/`).
- [x] Refactor de filtros del mapa de Distribución con `shinyWidgets::selectizeGroupServer`
- [ ] Confirmar acceso de escritura al repo (`push: true`) vía correo enviado
- [ ] Decidir si el `renv.lock` actualizado se incluye en el PR de `frijol-cambios`,
  ya que arregla un problema real de reproducibilidad en Mac (beneficiaría a
  cualquiera que clone el repo en una Mac Intel moderna)
- [x] Panel de filtros del mapa (Condición/Estado/Especie): apilar hacia abajo en vez
  de desbordar, achicar altura de cada caja, y achicar el ancho a la mitad del panel
- [x] Cambiar capas base del leaflet a `providers$CartoDB.Positron` ("Mapa") y
  `providers$Esri.WorldImagery` ("Foto aérea"), patrón tomado de otro proyecto del
  usuario
- [x] Panel de filtros de Distribución: mover de lado izquierdo a lado derecho, pegado
  al borde (`absolutePanel`: `left = 220` → `right = 10`; ancho final `width = 150`)

## Ajustes de estilo al panel de filtros de Distribución (`#controls`)

Tras el refactor con `selectizeGroupServer`, se fueron ajustando detalles visuales del
panel flotante (`www/styles.css` + `absolutePanel(...)` en `ui.R`):
- `absolutePanel(..., width = 280)` (luego reducido a `150`, ver abajo) — antes no
  tenía ancho fijo, así que las etiquetas de selección múltiple (ej. varios estados)
  se extendían hacia la derecha en vez de apilarse. Con ancho fijo +
  `#controls .selectize-input { flex-wrap: wrap; height: auto; }` ahora sí se apilan.
- `#controls .form-group { margin-bottom: 7px; }` y `#controls label { margin-bottom: 2px; }`
  — la mitad de los valores por defecto de Bootstrap (15px y 5px), menos espacio
  vertical entre cada filtro.
- `#controls .selectize-input { min-height: 18px; padding: 4px 8px; font-size: 13px; }`
  — cajas más bajas (antes ~36px de alto).
- **Alineación a la derecha, pegado al control de capas del mapa ("Mapa"/"Foto aérea"):**
  intentos:
  1. `absolutePanel(right = 20)` → visualmente aún se veía separado del borde.
  2. `absolutePanel(right = 0)` — el usuario seguía viendo un espacio grande a la
     derecha en su captura de pantalla; probablemente esa captura era de un estado
     anterior sin recargar. Al medir con JS en el navegador de pruebas
     (`getBoundingClientRect()`), confirmé que con `right = 10` el borde derecho del
     panel (`#controls`) coincide EXACTO con el borde derecho del control de capas de
     leaflet (`.leaflet-control-layers`) — ambos en el mismo píxel.
  3. El verdadero problema no era la posición del panel sino el **contenido de
     adentro**: se había angostado cada caja a `width: 50% !important` (petición
     anterior de "reduce el espacio... a la mitad"), y como el contenido queda
     alineado a la izquierda por defecto dentro del panel, dejaba un hueco vacío visible
     a la derecha — parecía que el panel "no llegaba" al borde, cuando en realidad el
     panel sí estaba en el lugar correcto, solo que su contenido no llenaba todo su
     ancho.
     → Solución: en vez de cajas al 50% dentro de un panel ancho (280px), se achicó
     **el panel mismo** a `width = 150` y las cajas quedaron al `100%` de ese panel
     angosto — así no queda espacio vacío entre el contenido y el borde derecho.
     ```css
     #controls .shiny-input-container {
       width: 100% !important;
     }
     ```
  **Lección:** cuando algo "no se ve alineado" visualmente, antes de seguir ajustando
  la posición del contenedor vale la pena medir con
  `document.querySelector(...).getBoundingClientRect()` en la consola del navegador
  — puede que el contenedor ya esté bien y el problema sea el contenido de adentro.
- **Posición vertical:** se cambió de `bottom = 250` a `top = 166` para que el panel
  quede en la parte superior derecha, justo debajo del control de capas de leaflet
  ("Mapa"/"Foto aérea") sin encimarse con él. Un `top = 90` intermedio quedó
  encimado — 166px lo deja limpio debajo.
  Valores finales del panel: `absolutePanel(id = "controls", top = 166, right = 10,
  width = 150, draggable = TRUE, ...)`.

## Menú lateral: nombres largos que se cortaban

"Proporción de especies de frijol por estado" se cortaba en el sidebar (AdminLTE aplica
`white-space: nowrap` a los `menuItem`, así que el texto largo se truncaba en vez de
acomodarse). Se resolvió con CSS genérico en `styles.css` —aplica a cualquier ítem
largo, no solo a ese— en vez de meter un salto de línea manual en el texto:
```css
.sidebar-menu > li > a {
  white-space: normal;
  line-height: 1.3;
}
/* el ícono se alinea arriba para no quedar centrado respecto a 2 renglones */
.sidebar-menu > li > a > .fa,
.sidebar-menu > li > a > svg {
  vertical-align: top;
  margin-top: 2px;
}
```
Verificado en navegador: ahora se lee completo en dos renglones.

## Gráfica de Floración y fructificación (`graph4`)

Cambios pedidos: meses arriba **y** abajo, título en la figura, quitar las etiquetas de
eje "Especie" y "Mes", meses abreviados (Ene, Feb…) y sin rotación de 45°.

En `server.R`:
```r
scale_x_discrete(sec.axis = dup_axis()) +          # meses arriba y abajo
labs(title = "Época de floración y fructificación de los frijoles",
     x = NULL, y = NULL) +                          # quita etiquetas de eje
theme(plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.text.x = element_text(angle = 0, size = 12, hjust = 0.5, vjust = 0.5))
```

**Trampa importante con los meses cortos:** el primer intento fue
`scale_x_discrete(labels = meses_cortos, sec.axis = dup_axis())`, y **truena** con
`` `breaks` and `labels` have different lengths `` — combinar `labels=` con
`sec.axis`/`dup_axis()` en una escala **discreta** no funciona (el eje secundario
trata la escala como continua al pedir las etiquetas). En la app llegó a verse bien
en un caso, pero fallaba en otros → bug latente.
→ Solución: renombrar los **niveles del factor** en `FloFru1_data()`, no usar `labels=`:
```r
levels(FloFru1$Mes) <- c("Ene","Feb","Mar","Abr","May","Jun",
                         "Jul","Ago","Sep","Oct","Nov","Dic")
```
Así `dup_axis()` hereda las etiquetas cortas en ambos ejes sin conflicto.

**Verificación:** se probaron las 4 combinaciones de filtros (Floración/Fructificación ×
Cultivados/Silvestres) construyendo el gtable con `ggplot_gtable(ggplot_build(p))` y
confirmando que en todas aparecen `axis-b` (abajo) y `axis-t` (arriba) sin errores.
Además se generó el PNG real y se inspeccionó: título, meses cortos horizontales arriba
y abajo, sin etiquetas de eje.

### Altura de las gráficas: `plotOutput(height = "auto")`

Al quitar antes el CSS que forzaba la altura, `plotOutput` quedó con su alto por defecto
(400px) mientras `renderPlot` generaba imágenes de 1540px → **la figura se cortaba y la
página no crecía para poder hacer scroll** (medido: contenedor 400px vs imagen 1540px).
→ Se agregó `height = "auto"` a `plotOutput` de `graph2` y `graph4`, para que el
contenedor tome la altura de la imagen que calcula `renderPlot`. Verificado: contenedor
1540px = imagen 1540px, sin recorte, y la página se vuelve scrolleable.
También se extrajo el cálculo de altura a reactivos (`alto_graph2()`, `alto_graph4()`)
para no duplicar la fórmula.

Se probó un enfoque alternativo con `uiOutput` + `renderUI` (para fijar la altura en
píxeles explícitos) pero **no funcionó** en pruebas — se descartó y se volvió a
`height = "auto"`.

### Título dinámico según los filtros

El título ya no es fijo: se arma con los dos filtros activos (Epoca y Tipo).
```r
titulo_graph4 <- paste0("Época de ", tolower(input$Epoca),
                        " de los frijoles ", tolower(input$Tipo))
```
Los valores vienen tal cual del Excel (`Floración`/`Fructificación` y
`Cultivados`/`Silvestres`), así que basta `tolower()` para integrarlos a la frase.
Las 4 combinaciones posibles:
- Época de floración de los frijoles silvestres
- Época de floración de los frijoles cultivados
- Época de fructificación de los frijoles silvestres
- Época de fructificación de los frijoles cultivados

Verificado en la app cambiando ambos filtros: el título se actualiza correctamente y
los acentos se ven bien.

### Selector de color (paleta FantasticFox1 de wesanderson)

El usuario pidió que la gente pueda elegir el color de la gráfica, usando la paleta
`FantasticFox1` del paquete `wesanderson`. Se instaló el paquete
(`renv::install("wesanderson")`, versión 0.3.7).

**`global.R`** — define la paleta con nombres legibles:
```r
library(wesanderson)
paleta_fox <- setNames(
  as.character(wes_palette("FantasticFox1")),
  c("Ocre", "Amarillo", "Azul", "Naranja", "Rojo")
)
```
Colores: `#DD8D29` (Ocre), `#E2D200` (Amarillo), `#46ACC8` (Azul), `#E58601` (Naranja),
`#B40F20` (Rojo).

**`ui.R`** — `pickerInput` de shinyWidgets en la pestaña `widgets3`, con cada opción
pintada de su propio color para que se vea qué se está eligiendo:
```r
pickerInput(
  inputId = 'color_fox', label = h6(strong('Color:')),
  choices = names(paleta_fox), selected = "Azul",
  choicesOpt = list(style = paste0("background-color:", unname(paleta_fox),
                                   "; color: white; font-weight: bold;")),
  width = 200
)
```

**`server.R`** — el color elegido es el extremo **alto** del degradado; el extremo bajo
se deriva aclarando ese mismo color, para que la escala combine sin importar cuál elija
el usuario (antes eran dos azules fijos `#deebf7`/`#3182bd`):
```r
color_alto <- unname(paleta_fox[input$color_fox])
color_bajo <- colorspace::lighten(color_alto, 0.85)
...
scale_fill_gradient(low = color_bajo, high = color_alto)
```
Se usa `colorspace::lighten()` con namespace explícito para evitar riesgo de
enmascaramiento entre los muchos paquetes que carga la app.

Default: "Azul" (`#46ACC8`), para mantener continuidad con el aspecto anterior.
Verificado en Chrome con clics reales: el desplegable muestra los 5 colores pintados y
la gráfica cambia al color elegido con su tono claro derivado.

**Observación de diseño:** el "Amarillo" (`#E2D200`) es el que menos contraste da entre
el tono claro y el fuerte — sigue siendo legible, pero es el más débil de los cinco para
este tipo de mapa de calor. Si en algún momento estorba, se puede quitar de la lista de
opciones sin tocar nada más.

## Rediseño de la gráfica de Altitud: perfil de montaña (`graph2`)

El usuario compartió el **"Perfil de vegetación y fauna de Sierra Nevada (Granada)"**
del Atlas Nacional de España (IGN) como referencia de diseño: una silueta de montaña con
la vegetación colocada a su altitud y etiquetas conectadas a su posición. Pidió rehacer
la gráfica de Altitud con ese estilo, reemplazando el `geom_dumbbell` anterior.

### Datos: por qué no se puede copiar el diseño tal cual

Se revisaron los datos antes de diseñar, y salió una diferencia clave con la referencia:
- 59 especies con datos de altitud (rango global 0–3200 m), nombres de hasta 38 caracteres
- **Los rangos se traslapan muchísimo**: mediana de amplitud por especie = 1300 m, y
  46 de las 59 tienen su promedio entre 1000 y 2500 m
- En Sierra Nevada cada piso de vegetación ocupa su propia franja altitudinal; aquí no.
  Si cada nombre se coloca a su altitud, casi todos se encimarían en la franja media.

→ Solución: **repartir las especies horizontalmente** (ordenadas por altitud, usando el
selector que ya existía) para que suban en escalera por la ladera. Cada especie tiene su
propio carril en X, así que los nombres rotados 90° **no pueden chocar** por muchas que
sean — el amontonamiento se resuelve por construcción, no por filtrar.

### Diseño final

- **Eje Y = altitud** (0–3000 m con marcas cada 1000 m), que es lo intuitivo y lo que
  hace que se lea como montaña. El eje X no tiene etiquetas (solo ordena).
- **Silueta de montaña** de fondo: polígono relleno `#EFE0C4`. La cresta pasa
  **exactamente por el valor de cada especie**, sin suavizar, y se cierra bajando a
  `y = 0` en ambos extremos para formar un polígono:
  ```r
  montana <- data.frame(x = c(0.3, LL$pos, n + 0.7),
                        y = c(0,   LL$ordenar, 0))
  ```
  Usa la **variable de ordenamiento elegida**, y como las especies ya vienen ordenadas
  por ella la ladera siempre sube limpia, se ordene por promedio, máximo o mínimo.
  *(Primero se probó que la cresta siguiera el `maximo` fijo: con el orden por "mínimo"
  la montaña salía dentada porque cresta y orden usaban variables distintas.)*

  **Se quitó el suavizado con `loess` de la ladera principal.** Se usaba
  `loess(ordenar ~ pos, span = 0.9)`, pero `loess` dibuja la *tendencia*, no los datos:
  pasa cerca de los puntos pero no por ellos, y eso dejaba **los puntos flotando sobre
  la ladera** — medido: 44 m de desviación promedio y hasta 168 m en el peor caso. Con
  la cresta exacta la desviación es 0. No se ve dentada porque los valores consecutivos
  de especies ordenadas están muy cerca; queda una rugosidad sutil que hasta parece
  terreno real.

### Montaña en tres capas (mínimo, promedio, máximo)

Idea del usuario: ver las tres laderas a la vez para que se aprecie toda la franja
altitudinal que ocupa el género. Se dibujan **tres polígonos anidados**, del más claro
(máximo, `#F7EFE0`) al más oscuro (mínimo, `#CBB185`).

**El primer intento con los tres valores exactos no sirvió:** salía una sierra de picos
caóticos. La razón es que las especies se ordenan por UNA variable, así que solo esa
ladera sube limpia; las otras dos saltan bruscamente entre especies vecinas (una especie
con promedio alto puede tener un mínimo muy bajo).

**Solución:** la ladera de la variable **elegida en el selector** va exacta —para que los
puntos sigan posados en ella— y **las otras dos se suavizan** con `loess(span = 0.5)`,
funcionando como envolventes de contexto.

⚠️ **Trampa encontrada al verificar:** al suavizar por separado, las curvas pueden
cruzarse, así que hay que forzar `mínimo <= promedio <= máximo`. Pero el ajuste debe
tocar **siempre las suavizadas y nunca la exacta**. La primera versión usaba
`pmax(cresta_max, cresta_prom)` a secas, y al ordenar por "máximo" eso *subía* la cresta
exacta para esquivar el promedio suavizado → **los puntos quedaban hasta 213 m fuera de
su ladera**. Se corrigió con lógica por caso (ver `if (input$var11 == ...)` en
`server.R`). Verificado: en las tres opciones de orden el anidamiento se respeta y la
desviación punto-ladera es **0.0 m**.

El subtítulo explica las bandas, porque tres tonos sin leyenda son ambiguos: alguien
podría creer que la banda oscura "es la montaña" en vez de representar los mínimos.

**Nota de honestidad del dato:** las dos laderas suavizadas ya no representan valores
exactos sino tendencias. Es aceptable porque son fondo de contexto —los datos precisos
siguen estando en los puntos y sus tooltips— pero es justo lo contrario del criterio que
se aplicó a la ladera principal. Vale tenerlo presente si alguien pregunta.
- **Un punto por especie** a la altitud seleccionada (`ordenar`), no un rango.
- **Nombre rotado 90°, 1000 m arriba de su punto** (`separacion <- 1000`). Al estar cada
  nombre pegado a su propio punto, suben en escalera siguiendo la ladera — como en la
  referencia.
  *(Versión intermedia descartada: nombres alineados todos a una misma altura con una
  línea gris tenue conectándolos a su rango min–máx. Se veía ordenado pero el usuario
  prefirió el escalonado y quitar las líneas de rango.)*
- **Nombres abreviados**: `"Phaseolus vulgaris"` → `"P. vulgaris"`, con
  `sub("^Phaseolus\\s+", "P. ", ...)` en una columna `etiqueta` (se conserva `Especie`
  completa). Acorta ~9 caracteres cada nombre y despeja mucho la gráfica.
- Sin líneas de mínimo/máximo: se simplificó a decisión del usuario.

### Colocación de los nombres: cuatro intentos hasta dar con la buena

Esta parte costó varias vueltas. Queda documentado el porqué de cada descarte para no
repetirlas:

1. **Rotados 90°, alineados todos a una misma altura**, con hilo gris al rango min–máx.
   Ordenado, pero el usuario prefirió que cada nombre siguiera a su propio punto.
2. **Rotados 90°, cada uno pegado a su punto.** Funcionaba y no chocaban (cada nombre
   en su carril vertical), pero se leen girando la cabeza.
3. **Rotados 45°.** Descartado: con ~59 especies cada etiqueta barre en diagonal varios
   carriles y quedan **ilegibles** (verificado en pantalla). 45° solo tendría sentido con
   muy pocas especies.
4. **Horizontales atados a su propio valor + escalón acumulado** (200 m de despegue,
   20 m por orden). Descartado: al atarlos a la altitud real quedan **encimados donde
   los datos se amontonan y separadísimos donde saltan**, y para respetar la separación
   mínima la gráfica se disparaba a ~2800 px de alto.

5. **Horizontales repartidos de forma pareja** dentro de la banda de los datos
   (`seq(min, max, length.out = n)`). Garantizaba cero encimamientos y altura
   razonable, pero el usuario lo descartó: prefiere que cada nombre esté atado a su
   propio valor aunque algunos se encinen.

**Estado actual — horizontales, atados a su propio valor:**
```r
DESPEGUE <- 80   # metros que el nombre se levanta sobre su propio valor
y_nombres <- function(LL, alto_px) LL$ordenar + DESPEGUE
```
Simple y directo: cada nombre queda `DESPEGUE` metros encima de su punto, con un hilo
gris tenue conectándolos. Se probaron 1000 → 200 → 40 → 80 m.

**Los nombres se alternan izquierda / derecha** — idea del usuario, y resultó ser **la
solución al encimamiento**: los nombres que chocan son siempre vecinos en el orden, así
que al mandarlos a lados opuestos dejan de compartir el mismo espacio horizontal.
```r
LL$lado     <- ifelse(LL$pos %% 2 == 1, -1, 1)
LL$x_nombre <- LL$pos + LL$lado * 0.4
LL$h        <- ifelse(LL$lado < 0, 1, 0)   # hjust: 1 termina en el punto, 0 arranca
geom_text(aes(x = x_nombre, y = y_nombre, label = etiqueta, hjust = h), ...)
```
(`hjust` funciona como aesthetic en ggplot2, así que puede variar por fila.)

Antes de alternar se probó mandarlos **todos a la izquierda**
(`hjust = 1, nudge_x = -0.35`), también idea del usuario, para **quitar la franja en
blanco que quedaba a la derecha**: como la montaña sube hacia la derecha, el espacio
vacío está arriba a la izquierda y los nombres lo aprovechan. Eso resolvió el hueco
(antes salían a la derecha con `expansion(mult = c(0.01, 0.35))`, y ese 35% se veía
como espacio muerto). Con el alternado, el aire va parejo a los dos lados:
`expansion(mult = c(0.13, 0.13))`.

**Línea que une el punto con su nombre:** punteada y más marcada, para que se siga bien
—`colour = "grey45", linewidth = 0.4, linetype = "dashed"` (antes era gris muy tenue y
continua, casi no se veía).

Altura de la gráfica: `max(650, n * 15 + 130)`, ~15 px por especie.

**Nota:** se llegó a implementar a mano un algoritmo de descolisión (empujar hacia arriba
solo los nombres que chocaban, y solo lo mínimo) pero se quitó. Al final lo resolvió
`ggrepel`, ver abajo.

### Solución final al encimamiento: ggrepel

Aun con el alternado izquierda/derecha quedaban nombres encimados. Lo resolvió
**`ggrepel`** (0.9.8), que no es jitter (ruido al azar) sino que *empuja* activamente las
etiquetas hasta que dejan de tocarse.

**Clave: `ggiraph` trae `geom_text_repel_interactive()`**, así que no hubo que elegir
entre etiquetas legibles y hover — se conservan las dos cosas.

Cambios que trajo:
- `geom_text_interactive` → `geom_text_repel_interactive`, anclado directamente en el
  punto (`x = pos, y = ordenar`) en vez de en una posición calculada a mano.
- **Se quitó la `geom_segment_interactive` manual**: ahora repel dibuja su propia línea
  guía (`segment.linetype = "dashed"`). Es necesario, porque si repel mueve la etiqueta,
  una línea fija se quedaría apuntando al vacío.
- El alternado izquierda/derecha se conserva pero como **sesgo** (`nudge_x = lado * 0.6`)
  en vez de posición fija: repel decide el lugar final.
- Se limpió el código muerto que quedó: `x_nombre`, `h` y la función `y_nombres()`.

⚠️ **`max.overlaps = Inf` es imprescindible.** Por defecto ggrepel vale 10 y **descarta
etiquetas en silencio** cuando no encuentra dónde ponerlas — con 59 especies se habrían
perdido decenas de nombres sin ningún aviso. Verificado explícitamente capturando los
mensajes de `ggsave()`: **0 etiquetas descartadas**.

También se fija `seed = 42` (el acomodo de repel es estocástico) para que la figura salga
igual en cada render, y `min.segment.length = 0` para que siempre dibuje la línea guía.

### Interactividad al pasar el mouse (ggiraph)

El usuario pidió que al pasar el mouse por un punto se resaltaran su nombre y su línea.
Se resolvió con **`ggiraph`** (0.9.6), que era la herramienta correcta aquí:

- Renderiza el ggplot como **SVG** en vez de PNG, así el hover es instantáneo y
  del lado del navegador (sin volver a dibujar nada en el servidor).
- El aesthetic **`data_id`** agrupa elementos: se le pasa `data_id = Especie` al punto,
  a la línea punteada y al nombre, así que **pasar el mouse por cualquiera de los tres
  resalta los tres a la vez** — justo lo pedido.
- `opts_hover(css = ...)` define el resaltado y `opts_hover_inv(css = "opacity:0.30;")`
  atenúa todo lo demás, que es lo que de verdad hace que salte a la vista.
- También se agregó `tooltip` con el nombre completo de la especie y su altitud.

Cambios: `geom_segment`/`geom_point`/`geom_text` → sus variantes `*_interactive`,
`renderPlot` → `renderGirafe`, `plotOutput` → `girafeOutput`, y `library(ggiraph)` en
`ui.R` y `server.R`. La altura dinámica se pasa como `height_svg = alto_graph2() / 72`.

**Alternativas descartadas:**
- **plotly / `ggplotly()`** (ya estaba instalado): habría descuadrado el layout —
  es poco fiable con `geom_text` posicionado a mano y con el polígono de la montaña.
- **`hoverOpts` nativo de Shiny + volver a dibujar**: funciona con ggplot normal, pero
  regenera la imagen completa en cada movimiento del mouse; con ~59 especies se sentiría
  lento.

El resaltado quedó en rojo (`#B40F20`, de la misma paleta FantasticFox). **Se probó
además poner el texto en negritas al resaltar y se quitó**: engrosar la letra la volvía
difícil de leer.

### Líneas de referencia: altitud de las capitales estatales

Idea del usuario, y de las más valiosas de la sesión: como el eje Y ya es altitud, se
puede trazar una línea horizontal a la altura de una ciudad conocida y así la gente
ancla su propia referencia ("mi ciudad está a X metros, o sea que aquí crecen estos
frijoles").

- **Datos**: `capitales_altitud` en `global.R` — las 32 capitales con `ciudad`,
  `estado`, `cvegeo` y `altitud`. Se ordenan de menor a mayor y se arma
  `capitales_opciones`, que muestra `"Mérida (10 m)"` en el selector pero devuelve solo
  `"Mérida"`. **Valores verificados contra INEGI** (ver abajo).
- **UI**: `pickerInput` con `multiple = TRUE` y buscador, en la pestaña de Altitud.
  Arranca **sin ninguna seleccionada** (`selected = character(0)`) para no saturar.
  Permitir varias es deliberado: comparar Mérida (10 m) contra Toluca (2660 m) es
  didáctico.
- **Dibujo**: `geom_hline` (azul `#1F6F8B`, `linetype = "longdash"`) más un
  `geom_label` con el texto `Ciudad · N m`. La capa se construye como una `list()` de
  geoms (`capa_capitales`) y se inserta **justo después del polígono de la montaña**,
  para que quede por debajo de los puntos y nombres y no los tape. Cuando no hay
  ciudades seleccionadas la variable vale `NULL`, y sumarle `NULL` a un ggplot es
  válido — no hace falta un `if` alrededor del `+`.
- La etiqueta se ancla con **`x = -Inf`** (+ `hjust = 0`), que la pega al borde
  izquierdo del panel sin importar cuántas especies haya ni cómo cambien los filtros.
  Antes estaba en una `x` fija (0.5) que se despegaba del borde.
- Se filtra `caps$altitud <= techo` por si alguna ciudad quedara fuera del rango visible.

**Detalle:** `label.size` está deprecado en ggplot2 3.5+ para `geom_label`; el
reemplazo es `linewidth` (se usa `linewidth = 0` para quitarle el borde a la etiqueta).

#### Verificación de las altitudes contra INEGI

Los valores originales se pusieron de memoria. Se verificaron contra el **Catálogo Único
de Claves de Áreas Geoestadísticas de INEGI** (archivo `AGEEML_*.csv`, julio 2026).

**Resultado:** 27 de 32 estaban dentro de ±20 m y el error absoluto promedio era de
16 m. Solo dos necesitaban corrección real: **Ciudad de México (2350 → 2230)** y
**Chilpancingo (1360 → 1255)**. Cuatro ya estaban exactas.

**Cómo se filtró.** El catálogo trae 296,658 localidades; hacen falta 32.

- **`CVE_LOC = 0001` NO es la capital del estado, es la cabecera *municipal*.** Cada uno
  de los ~2,476 municipios tiene su `0001`. Ese filtro es solo el primer paso: baja de
  296 mil a 2,476. El segundo paso es escoger, dentro de cada entidad, el municipio que
  es capital.
- Se buscó cada capital por nombre **dentro de su `CVE_ENT`**, sobre `NOM_LOC`. Las 32
  empataron con exactamente una fila; solo Tlaxcala dio dos candidatas y se resolvió
  sola (*Santa Cruz Tlaxcala* es otro municipio).

**Tres trampas del archivo**, todas encontradas en la práctica:

1. **El CSV está mal formado.** Los campos `LATITUD`/`LONGITUD` traen comillas sin
   escapar (`21°52´47.362"N`) dentro de un campo entrecomillado, lo que rompe cualquier
   lector de CSV estándar. Se leyó partiendo por el separador literal `","`, que es
   seguro aquí porque ningún nombre contiene esa secuencia. **El encabezado, en cambio,
   no trae comillas** y hay que partirlo con coma simple.
2. **El archivo viene en Latin-1 y con CRLF**, no en UTF-8.
3. **`iconv(..., "ASCII//TRANSLIT")` en macOS convierte "É" en "'E"**, no en "E". Eso
   hizo fallar exactamente las 6 capitales con acento (Tuxtla Gutiérrez, Oaxaca de
   Juárez, Querétaro, San Luis Potosí, Culiacán, Mérida) sin ningún error visible. El
   reemplazo confiable es `chartr("ÁÉÍÓÚÜÑáéíóúüñ", "AEIOUUNaeiouun", toupper(s))`.

**Dos decisiones de contenido:**

- **La Ciudad de México no existe como localidad única** en el catálogo: está partida en
  16 alcaldías. Se usa **Cuauhtémoc (`090150001`, 2230 m)**, que es donde está el Zócalo.
- `ciudad` y `estado` guardan los **nombres comunes que usa la app**, no los oficiales de
  INEGI ("Coahuila", no "Coahuila de Zaragoza"). Verificado que los 32 valores de
  `estado` empatan con la columna `Estado` de los datos de Phaseolus, así que la tabla es
  unible con ellos.

**Trazabilidad:** la columna `cvegeo` guarda la clave de 9 dígitos de la localidad, así
que cada altitud se puede rastrear hasta su renglón de origen.

**El CSV de INEGI está en `.gitignore`** (53 MB). La app no lo necesita para correr: los
32 registros están escritos directamente en `global.R`. Se conserva local por si hay que
volver a consultarlo.

### Contador de especies en la esquina superior izquierda

Un número grande con las especies que se están mostrando, que cambia al filtrar por
estado (Chihuahua → 13, todos los estados → 59). Da idea inmediata de la riqueza de la
selección.

```r
annotate("text", x = -Inf, y = max(LL$ordenar), label = n,
         hjust = -0.25, vjust = 0.5,
         size = 20, fontface = "bold", colour = "#7A5C2E") +
annotate("text", x = -Inf, y = max(LL$ordenar),
         label = if (n == 1) "especie" else "especies",
         hjust = -0.32, vjust = 4, size = 6, colour = "#7A5C2E")
```

Tres decisiones que importan:

- **`y = max(LL$ordenar)`**, no `y = Inf`. El primer intento lo ancló al borde superior
  del panel y **se leía como una tercera línea del subtítulo**, no como parte de la
  figura. Bajarlo a la altura de la especie más alta lo integra a la gráfica. `x = -Inf`
  sí se conserva: lo pega al borde izquierdo sin depender del número de especies.
- **Va al final de la cadena de `+`**, después de `geom_text_repel_interactive`, para que
  se dibuje **encima**: ggrepel no sabe que la anotación existe y podría mandar un nombre
  a esa esquina.
- **Arriba a la izquierda es la zona vacía** de esta gráfica precisamente porque las
  especies se ordenan de menor a mayor altitud: la montaña asciende de izquierda a
  derecha, así que a la altura del máximo el lado izquierdo está despejado.

**Trampa de `vjust`:** se mide en altos de **su propia letra**, no de la del elemento
anterior. Como el número es `size = 20` y la palabra `size = 6`, la palabra necesita un
`vjust` grande solo para librar los dígitos. No es un valor "mágico": es la altura del
número expresada en altos de la palabra, y por eso los dos valores se mueven juntos
(`0.5 / 4` anclados al máximo; eran `1.05 / 5.8` anclados al borde).

**Verificado** en el caso de rango más comprimido (Chihuahua, 13 especies, 1600–2200 m)
con una capital seleccionada: el contador no toca la montaña, ni las etiquetas, ni la
línea de la ciudad.

`n` ya estaba calculado (`n <- nrow(LL)`), así que no hubo que agregar ningún cálculo.

### Descartado: animar la transición entre mínimo / promedio / máximo

Se evaluó animar la gráfica (estilo D3.js) para que los puntos y sus nombres se
deslizaran a su nueva posición al cambiar el selector. **Se descartó por diseño, no por
dificultad técnica.**

**La razón:** las especies se ordenan por la variable seleccionada, así que al cambiar el
selector **no solo cambian de altura: cambian de lugar en el eje X**. Medido sobre las 59
especies:

| Cambio | Lugares que se mueve una especie (promedio) | Peor caso | Se quedan igual |
|---|---|---|---|
| mínimo → promedio | 9.4 | 37 | 5 de 59 |
| promedio → máximo | 8.8 | 41 | 2 de 59 |
| mínimo → máximo | **16.5** | **56** | **1 de 59** |

Correlación de orden (Spearman) entre mínimo y máximo: **0.25** — órdenes casi
independientes. Es esperable: una especie de rango amplio tiene mínimo bajo *y* máximo
alto a la vez.

Por eso la animación no se vería como puntos subiendo, sino como 59 puntos cruzándose en
horizontal mientras suben y bajan, con ggrepel resolviendo las etiquetas desde cero. La
animación solo comunica si el objeto que se mueve es el mismo de un estado a otro, y aquí
no lo es.

**La bifurcación era excluyente:** conservar el orden (montaña como perfil ascendente
limpio, animación ilegible) o congelarlo (animación legible, montaña deja de ser un
perfil ordenado en dos de las tres opciones). Se decidió conservar el orden: la gráfica
actual ya comunica el rango con las tres bandas.

**Sobre las herramientas**, por si se retoma en otro proyecto:

- **Animar el SVG de ggiraph con JS** — trampa. Shiny reemplaza el SVG completo en cada
  render, y la estructura interna del SVG de ggiraph no es API pública: cambia entre
  versiones y se rompe en silencio.
- **`echarts4r`** — camino medio real (transiciones y hover nativos), pero su evasión de
  colisiones de etiquetas es mucho más débil que ggrepel.
- **D3 puro (`r2d3`)** — control total, pero implica reescribir la gráfica en JS: se
  pierden ggplot2, el suavizado loess, el tema y ggrepel (habría que rehacerlo con
  `d3-force`), y la app queda partida en dos tecnologías.
- **`gganimate`** — herramienta equivocada: produce un GIF que se reproduce solo, no
  responde al selector.

## Interactividad en las otras dos gráficas

Se extendió el mismo patrón de ggiraph a Floración y al waffle.

**Floración (`graph4`)** — cambio directo: `geom_tile` → `geom_tile_interactive` con
`data_id = Especie`, así que al pasar el mouse por **cualquier mes** se resalta el
**renglón completo de la especie**. `renderPlot` → `renderGirafe`, `plotOutput` →
`girafeOutput`.

**Waffle (`graph3`) — hubo que reescribirlo.** La función `waffle()` del paquete genera
sus propios geoms internos, que no son interactivos. Se **reconstruyó la rejilla a mano**:
un waffle no es más que una cuadrícula de 10 filas donde cada cuadro vale 1%.
```r
FILAS <- 10
celdas <- data.frame(Especie = factor(rep(comunes$Especie, comunes$val1), ...))
idx <- seq_len(nrow(celdas)) - 1
celdas$fila    <- idx %% FILAS      # se llena por columnas, de abajo hacia arriba
celdas$columna <- idx %/% FILAS
```
Verificado: produce exactamente 100 celdas y 10 columnas, igual que la versión original.
La gráfica ya no depende del paquete `waffle` para dibujarse.

### Especies raras que desaparecían del waffle

**Problema detectado al reescribir el waffle:** las especies con menos de ~0.5% de los
registros redondean a 0% y no alcanzan a ocupar ni un cuadro, así que **desaparecían sin
aviso**. No es menor: en Oaxaca son 6 de 21 especies, y en Jalisco 6 de 28. Para una app
de biodiversidad, perder justo las especies raras es lo peor que puede pasar.

Un primer intento fue sacarlas también de la leyenda (porque aparecían con la casilla de
color vacía, que se veía como un error), pero eso empeoraba el problema: desaparecían por
completo.

**Solución:** se dibujan en una **fila aparte debajo de la rejilla** (`FILA_RARAS <- -2.2`),
con su color y su tooltip, separadas por un hueco para que **no distorsionen las
proporciones** del waffle. Conservan su entrada en la leyenda. Además se agrega una nota
al pie (`labs(caption = ...)`) que las lista por nombre. El tooltip de esas celdas muestra
el porcentaje exacto (`pct_real`, sin redondear) para que se vea cuán raras son.

### La leyenda del waffle se encimaba con la nota al pie

**Problema:** con muchas especies la leyenda crecía hacia abajo más que la propia gráfica
y su última entrada quedaba **encima de la nota al pie** de las especies raras. Se veía en
Michoacán (18 especies) y Nayarit (20). El SVG tiene alto fijo (`height_svg = 7`), así que
la leyenda no tenía a dónde crecer.

**Solución** — una línea, en `guides()`:

```r
guides(fill = guide_legend(nrow = 11, title.theme = element_text(size = 20)))
```

`nrow = 11` topa la leyenda a 11 renglones; a partir de ahí `guide_legend` **se desborda a
una segunda columna** en vez de seguir hacia abajo. Como `byrow = FALSE` es el valor por
defecto, llena columna por columna, así que el orden de lectura (de más a menos frecuente)
se conserva.

No hay que ponerle un `if` según el número de especies: ggplot2 calcula
`ncol = ceiling(n / nrow)`, de modo que con 9 especies (Colima) sigue saliendo **una sola
columna**. El mismo parámetro cubre los dos casos.

**Costo:** la leyenda a dos columnas ocupa más ancho y el waffle se encoge un poco. Se
verificó que sigue legible en los tres casos.

**Verificado** renderizando a PNG los casos extremos, sin levantar la app: Michoacán
(18 → 11+7), Nayarit (20 → 11+9) y Colima (9 → una columna). Para revisar solo el acomodo
de una gráfica, reproducirla en un script con `ggsave()` es mucho más rápido que reiniciar
Shiny.

### Paletas del waffle: combinar paletas en vez de interpolar una

El usuario pidió varias opciones de color con paletas de wesanderson. **El problema:** esas
paletas traen solo 4-6 colores y el waffle puede llegar a ~22 especies; interpolar una sola
paleta hasta 22 deja tonos casi idénticos entre especies vecinas.

**Solución (idea del usuario):** cada opción **encadena varias paletas** en vez de estirar
una. Definido en `combos_waffle` en `global.R`:

| Combo | Paletas encadenadas | Colores únicos |
|---|---|---|
| Vívida | Zissou1 + Darjeeling1 + FantasticFox1 + Royal1 + Chevalier1 | 23 |
| Tierra y verdes | Cavalcanti1 + Moonrise2 + Royal2 + IsleofDogs2 + Chevalier1 | 23 |
| Cálida | GrandBudapest1 + Rushmore1 + BottleRocket2 + GrandBudapest2 + Moonrise1 | 22 |
| Variada | AsteroidCity1 + AsteroidCity2 + FrenchDispatch + IsleofDogs1 + Darjeeling2 | 27 |

**Verificado: ninguna combinación repite colores** (0 duplicados en las cuatro), y el waffle
dibuja **como máximo 22 especies** (Jalisco; mediana 11). Es decir, cada especie siempre
recibe un color genuinamente distinto y la interpolación de respaldo
(`colorRampPalette`, en `colores_waffle()`) nunca se activa en la práctica.

Se evaluaron y descartaron para los combos: **Darjeeling1 como paleta única** (al
interpolar de rojo a verde pasa por grises sucios) y **Moonrise3** (demasiado lavada para
distinguir especies). El paquete **`ghibli`** se consideró pero no hizo falta: con 0
repetidos y máximo 22 especies, ya sobran colores. Sería la vía si algún día se superan 27.

**Nota:** el hover de ggiraph baja mucho la exigencia sobre la paleta — aunque dos tonos se
parezcan, pasar el mouse aísla la especie y su entrada en la leyenda.

### Riqueza de especies por estado (dato de referencia)

Salió al revisar el waffle, y contradice la intuición de que Oaxaca y Morelos encabezarían:

| Estado | Especies | Visibles en waffle | Registros |
|---|---|---|---|
| Jalisco | 28 | 22 | 633 |
| Durango | 23 | 20 | 237 |
| Guerrero | 21 | 15 | 342 |
| Oaxaca | 21 | 15 | 638 |
| Sinaloa | 21 | 21 | 109 |
| Morelos | 10 | 10 | 184 |

⚠️ Esto es riqueza **en este conjunto de datos**, no diversidad biológica real: refleja
esfuerzo de colecta. Morelos tiene 184 registros contra 633 de Jalisco, así que su número
bajo puede ser submuestreo.

### Tamaños de texto de la gráfica de Altitud

| Elemento | Tamaño | Dónde |
|---|---|---|
| Título | 18 | `plot.title` |
| Subtítulo | 16 | `plot.subtitle` |
| Marcas del eje Y | 12 | `axis.text.y` |
| Ciudades de referencia | 4 | `geom_label` |
| Nombres de especies | 4 | `geom_text` |

⚠️ **Ojo con las unidades, es la confusión clásica:** en `element_text()` (título,
subtítulo, ejes) el `size` va en **puntos**; en `geom_text()`/`geom_label()` va en
**milímetros**. No son comparables directamente — 1 mm ≈ 2.85 pt. Por eso el "4" de las
especies (≈11.3 pt) es visualmente parecido al "12" del eje, no tres veces más chico.
- Subtítulo dinámico según el selector, con concordancia de género corregida
  ("altitud **máxima**", no "altitud máximo", porque los valores del selector son
  masculinos: promedio/máximo/mínimo).

### Filtro de estados (selección múltiple)

Se agregó `pickerInput` con `multiple = TRUE` para filtrar por estado. Reduce bien:
mediana de 10 especies por estado, máximo 27 (Jalisco), contra 59 con todos.
Incluye buscador (`liveSearch`), botones Todos/Ninguno (`actionsBox`) y texto
"N estados seleccionados" (`selectedTextFormat = "count > 2"`). Arranca con todos
seleccionados.

**Semántica de la agregación** (confirmada con el usuario): al seleccionar varios
estados, los registros de todos ellos **se agrupan juntos** — el mínimo es el más bajo
de la selección, el máximo el más alto, y el promedio la media de todos los registros
individuales. Eso deja el promedio **ponderado por número de colectas** (si Jalisco
aporta 100 registros y Oaxaca 5, el promedio se recarga a Jalisco). Es el mismo criterio
que ya usaba la app; el usuario lo confirmó explícitamente ("continua con el calculo
como esta ahora").

### Limpieza asociada

`Mex5`, `Mex7`, `Mex8` y `Mex9` en `global.R` precalculaban los rangos altitudinales,
pero quedaron **sin uso** al pasar el cálculo al reactivo `Mex10()` (que ahora depende de
los estados elegidos). Se eliminaron. Bonus: eran los que producían el warning de
arranque `ningún argumento finito para min; retornando Inf` — ya no aparece.

### Solo estados de México: un único filtro en `Mex3`

Durante un tiempo la app tuvo **dos data frames**: `Mex3` (todo) y `Mex4` (solo México).
Las gráficas usaban `Mex4`, pero el **mapa de Distribución y el selector del waffle
usaban `Mex3`**, así que ahí seguía apareciendo *Arizona* en la lista de estados. Lo
detectó el usuario al filtrar en Distribución.

**Solución:** el filtro se subió a `Mex3`, que ahora es la única fuente de datos de la
app. `Mex4` quedó siendo una copia idéntica y **se eliminó**; sus 4 usos en `server.R` y
`ui.R` apuntan ahora a `Mex3`.

```r
# dentro de la cadena que construye Mex3
dplyr::filter(!Estado %in% c("Huehuetenango", "Arizona", "New Mexico", "Texas")) %>%
```

Son 18 registros de 5,720 (Arizona 11, New Mexico 4, Texas 3; Huehuetenango ya salía
antes). Quedan **5,702 registros y 32 estados**.

**La lección:** mantener dos data frames que difieren en un filtro es una fuente
silenciosa de inconsistencias — nadie recuerda cuál usa cada pestaña, y la que usa el
"equivocado" no da error, solo muestra de más. Si el criterio aplica a toda la app,
va en un solo lugar.

**Detalle de factores:** el filtro va **dentro de la cadena**, antes de
`Mex3$Estado <- as.factor(...)`. Si se filtrara después, el nivel del estado excluido
seguiría existiendo aunque no tuviera filas, y los selectores que leen
`levels(Mex3$Estado)` lo mostrarían igual. Verificado: 32 niveles = 32 valores presentes,
sin niveles fantasma.

## Selector de paletas en el mapa de Distribución

Tres opciones de color en la esquina inferior izquierda del mapa: **Paleta 1** (la
original) y dos nuevas hechas con wesanderson.

**El criterio de diseño:** con 60 especies y sin leyenda, el color **no puede** servir
para identificar especies — la vista humana distingue con confianza entre 8 y 12
colores. Su función es transmitir la **diversidad** de un vistazo; el detalle se consulta
con los filtros y el popup de cada punto. Por eso se conservaron muchos colores en vez de
reducir a 3 categorías.

**Cómo se armaron las paletas 2 y 3.** Cada una encadena 10 paletas de wesanderson y
pasa por tres filtros, en este orden:

1. **Quitar los colores casi idénticos** (distancia perceptual < 10 en espacio Lab).
2. **Quitar los casi blancos y casi negros** (L fuera de 18–82). Wesanderson tiene varios
   cremas y beige clarísimos que **sobre el mapa CartoDB.Positron, que es casi blanco,
   simplemente no se verían**. Este filtro no es obvio hasta que lo ves fallar.
3. **Reordenar por lejanía**: cada color es el más alejado posible del anterior. Como las
   paletas tienen menos de 60 colores y se reciclan, esto hace que los vecinos contrasten.

Resultado: 30 y 27 colores, distancia mínima 10.3 y 10.0, y **cero colores compartidos**
entre ambas. Para comparar, `rainbow_hcl(60)` tiene distancia mínima 6.

**Se reciclan, no se interpolan.** `rep_len()` repite la paleta hasta cubrir las 60
especies. Interpolar (`colorRampPalette`) generaría tonos intermedios casi idénticos y
destruiría justo el contraste que se buscó.

**El vector de colores va NOMBRADO por especie:**

```r
colores_mapa <- function(nombre) {
  setNames(rep_len(paletas_mapa[[nombre]], nlevels(Mex3$Especie)), levels(Mex3$Especie))
}
```

Eso es lo que hace que **cada especie conserve su color al filtrar**. Si se asignara por
posición dentro del subconjunto visible, filtrar cambiaría los colores de todo.

Se eliminó la columna `RatingCol`, que precalculaba un color fijo por especie en
`global.R`; ahora el color se resuelve al dibujar, según la paleta elegida.

### Tres tropiezos, todos sin mensaje de error

**1. `renderLeaflet` + `leafletProxy` con la pestaña oculta.** Separar el mapa base
(`renderLeaflet`) de los círculos (`observe` + `leafletProxy`) evita que se reinicie el
zoom, pero **el mapa arrancaba vacío**: la app abre en Introducción, así que el mapa aún
no existía cuando el observador mandó los círculos, y el mensaje se perdió. Los círculos
solo aparecían al tocar un filtro.

`outputOptions(output, "mymap1", suspendWhenHidden = FALSE)` corrige eso pero **provoca
otro problema**: Leaflet se inicializa con tamaño 0×0 y el mapa queda gris, sin tiles.

**Solución final:** volver a un solo `renderLeaflet` y conservar la vista leyendo el zoom
y el centro actuales:

```r
zoom_actual   <- isolate(input$mymap1_zoom)
centro_actual <- isolate(input$mymap1_center)
# ... y al final:
if (!is.null(zoom_actual)) mapa <- mapa %>% setView(centro_actual$lng, centro_actual$lat, zoom_actual)
```

**`isolate()` es imprescindible**: sin él, leer esos inputs —que el propio mapa actualiza
al moverse— crea un ciclo infinito de redibujado.

**2. `absolutePanel` con `left` se esconde detrás de la barra lateral.** Se posiciona
respecto al ancestro posicionado más cercano, que era `#wrapper` (la página completa),
así que `left = 25` caía dentro de la barra lateral de 200px. Poner `position: relative`
en el `tabItem` no funcionó. **Lo que sí funciona** es meter el panel y el mapa juntos en
un `div(style = "position: relative;")`. Así el `left` se mide desde el borde del mapa, y
sigue funcionando si la barra lateral se colapsa.

Con `right` no pasaba (por eso el panel de filtros nunca dio problema): el borde derecho
de la página y el del área de contenido coinciden.

**3. El navegador cachea `www/styles.css`.** Al agregar reglas nuevas, la app las sirve
bien pero el navegador sigue usando la versión vieja: el panel salía sin fondo. Se
verifica con `getComputedStyle(...).backgroundColor` y se resuelve recargando sin caché.
Vale la pena descartarlo antes de suponer que la regla CSS está mal escrita.

**Nota de rendimiento:** dibujar los 5,693 círculos toma varios segundos. Al probar en el
navegador hay que esperar a que `document.querySelectorAll('#mymap1 path').length > 0`
antes de concluir que algo falló — más de una vez pareció roto y solo estaba dibujando.

## Pestaña de Referencias

Los tres bloques de citas —proyecto, informe y base de datos— se sacaron de la
introducción a una pestaña propia, porque alargaban la página de entrada sin ser lo que
la gente va a leer primero.

Sigue el **mismo patrón que la Introducción**: el texto vive en su propio archivo,
`extra_files/frijol_referencias.md`, y se inyecta con `includeMarkdownNewTab()`. Eso
permite editar las referencias sin tocar código de R, y las ligas abren en pestaña nueva.

```r
tabItem(
  tabName = "referencias",
  fluidRow(
    column(width = 10, offset = 1,
      div(class = "contenido-frijol", style = "margin-top: 35px;",
          includeMarkdownNewTab("extra_files/frijol_referencias.md")))))
```

**El `margin-top: 35px` no es decorativo:** el cintillo superior mide 50 px y sin ese
margen el título de la pestaña **se le encimaba**. Se detectó midiendo en el navegador —
el `h1` quedaba a 45 px del tope.

En la introducción se dejó una línea que remite a la pestaña, para que nadie se quede sin
saber de dónde salieron los datos.

## Filtro de altitud en el mapa (deslizador + casilla)

Un `sliderInput` de rango y una casilla para quitar los registros sin dato, ambos en el
panel de filtros. El panel se ensanchó de 150 a 190 px porque el deslizador necesita
espacio para sus dos manijas y sus etiquetas.

```r
points_altitud <- reactive({
  d <- points()
  if (isTRUE(input$sin_altitud)) d <- d[!is.na(d$Altitud), ]
  r <- input$altitud_mapa
  if (is.null(r) || (r[1] <= RANGO_ALTITUD_MAPA[1] && r[2] >= RANGO_ALTITUD_MAPA[2]))
    return(d)
  d[!is.na(d$Altitud) & d$Altitud >= r[1] & d$Altitud <= r[2], ]
})
```

### ⚠️ La guarda del rango completo no es un detalle

**855 de los 5,702 registros no tienen altitud, y los 855 SÍ tienen coordenadas.** Son
puntos válidos del mapa a los que solo les falta ese atributo.

En R **un `NA` nunca cumple una comparación**, así que `Altitud >= min` los descarta
aunque el deslizador esté en su rango completo. Sin el `if` que corta antes de filtrar,
esos 855 puntos habrían desaparecido del mapa **desde el arranque**, sin que nadie tocara
el control — una pérdida del 15% de los datos que nadie habría notado.

Al acotar el rango sí salen, y eso sí es correcto: si no se sabe a qué altitud
pertenecen, no se puede afirmar que estén dentro de ninguna franja.

La casilla se agregó a propuesta del usuario, y mejoró el diseño: vuelve **explícita** una
decisión que iba a quedar escondida en la lógica del deslizador. Su etiqueta muestra el
conteo — "Quitar sin altitud (855)" — para saber cuánto se está quitando antes de marcarla.

**Verificado:** 5,693 puntos → 4,838 al marcar la casilla (exactamente −855), y 1,680 al
pedir el rango 2000–3200 m.

## Encuadre del mapa: zoom fraccionario y conservar la vista

**Problema 1.** México ocupaba el 62% del ancho disponible. La causa no eran los datos
—que ya estaban acotados al país— sino que **leaflet solo usa niveles de zoom enteros**
por defecto: México cabe en 5.5 pero no en 6, así que redondeaba a 5.

```r
leaflet(options = leafletOptions(zoomSnap = 0.25, zoomDelta = 1))
```

Con `zoomSnap = 0.25` arranca en 5.5 y ocupa el 87%. `zoomDelta = 1` se deja explícito
para que los botones `+` y `−` sigan moviéndose un nivel completo; si no, avanzarían de
cuarto en cuarto y se sentirían lentos.

**Problema 2.** Cada cambio de filtro o de paleta reconstruye el mapa y devolvía la vista
al encuadre inicial.

```r
zoom_actual   <- isolate(input$mymap1_zoom)
centro_actual <- isolate(input$mymap1_center)
# ... y al final, setView() si existen, fitBounds() si no
```

**`isolate()` es imprescindible:** sin él, leer esos inputs —que el propio mapa actualiza
al moverse— crea un ciclo infinito de redibujado.

### ⚠️ El camino "correcto" que no funciona aquí

Lo canónico sería separar el mapa: `renderLeaflet` para la base y un `observe()` con
`leafletProxy()` para los círculos, así no se reconstruye nada. **Se intentó y falló:**
la app arranca en Introducción, el observador mandaba los círculos antes de que el mapa
existiera y el mensaje se perdía. El mapa se veía vacío hasta tocar un filtro.

Y la corrección obvia, `outputOptions(output, "mymap1", suspendWhenHidden = FALSE)`,
rompe otra cosa: Leaflet se inicializa con tamaño 0×0 y el mapa queda gris, sin tiles.

Por eso quedó el bloque único con `isolate()`. No es lo más elegante, pero es lo que
funciona sin efectos colaterales.

## Resaltar las especies domesticadas en Altitud

Una casilla que pinta en **rojo y negritas** el nombre de las cinco especies domesticadas.

```r
resaltar <- isTRUE(input$domesticadas) &
  as.character(LL$Especie) %in% especies_domesticadas
LL$color_nombre <- ifelse(resaltar, "#B40F20", "grey15")
LL$face_nombre  <- ifelse(resaltar, "bold.italic", "italic")
# ... aes(colour = color_nombre, fontface = face_nombre)
scale_colour_identity() +
scale_discrete_identity(aesthetics = "fontface")
```

**Por qué con `aes()` y escalas identity, y no con un vector:** pasar un vector al
parámetro `colour` funciona, pero depende de que las filas queden en el mismo orden — y
**ggrepel las reacomoda**. Atándolo a los datos con `aes()` no hay forma de que se
desparejen.

`"bold.italic"` y no `"bold"`: la cursiva se conserva siempre, por la convención
tipográfica de los nombres científicos.

### La lista de domesticadas y el matiz de las variedades

En `global.R`, explícita y documentada. **Dos de las cinco no son la especie completa
sino una variedad:**

- `P. acutifolius var. acutifolius` es la cultivada; `var. tenuifolius` es la silvestre
- `P. lunatus var. lunatus` es la cultivada; `var. silvester` es la silvestre

Y los registros identificados solo hasta especie (`Phaseolus acutifolius` a secas) quedan
**fuera a propósito**: no se sabe si son la forma cultivada o la silvestre.

## Pestaña nueva: Altitud por especie

Muestra el gradiente completo de cada especie elegida —cada altitud donde se ha
registrado— en vez del resumen mínimo/promedio/máximo.

**Antes de construirla se compararon dos diseños** renderizando ambos a PNG: una montaña
combinada con todos los registros, o una montaña por especie con el eje X en porcentaje.
Se eligió la segunda porque con la primera *P. vulgaris* aportaba la mitad de los puntos y
dominaba la curva, dejando a las demás como puntitos sueltos. Con una sola especie
seleccionada las dos opciones dan la misma gráfica; la diferencia solo aparece al comparar.

### `distinct()` — la sugerencia que hizo legible la figura

Propuesta del usuario. Una misma altitud repetida en decenas de colectas aporta **un solo
punto**:

```r
d <- dplyr::distinct(d, Especie, Altitud, .keep_all = TRUE)
```

*P. vulgaris* pasó de **1,387 registros a 300 valores distintos**. En total, de 4,847 a
2,027.

### El eje X en porcentaje, no en conteo

Es lo que permite comparar especies con volúmenes muy distintos: una con 300 altitudes y
otra con 40, ambas van de 0 a 100%. El `if (n() > 1) ... else 50` evita una división entre
cero cuando una especie tiene un solo valor.

### Umbral de especies ofrecidas

```r
MIN_ALTITUDES_GRADIENTE <- 5
```

Con una o dos altitudes no hay gradiente, se ve ruido. El umbral cuenta **altitudes
distintas, no registros crudos**. Deja fuera 10 de las 59 especies, y una nota al pie lo
explica para que nadie piense que faltan datos por error.

### Menú anidado

Con dos pestañas de altitud, el menú se ordenó agrupándolas:

```r
menuItem("Altitud", icon = icon("certificate"), startExpanded = TRUE,
  menuSubItem("Altitud global",      tabName = "widgets1"),
  menuSubItem("Altitud por especie", tabName = "altitud_especie"))
```

**El `menuItem` padre NO lleva `tabName`**: competiría con sus hijos por la selección.
Verificado que el atajo desde la caja de la Introducción (`updateNavbarPage` a `widgets1`)
sigue funcionando y **abre el submenú solo**.

## Cuadro multicolor en el waffle

Vino de una crítica de los colegas del usuario: *si las especies raras son parte del
universo de frijoles, deberían verse en la figura*, no debajo de ella.

**La regla, propuesta por el usuario:** se le quita un cuadro a la especie más pequeña de
la rejilla, ese cuadro se vuelve un **cuadro multicolor** que representa al grupo, y esa
especie baja a la fila inferior junto con las raras. La rejilla conserva sus 100 cuadros.

El cuadro no es un degradado: es **una franja por especie excluida**, con su color.

```r
franjas <- data.frame(
  xmin = cx - 0.45 + (0:(ne - 1)) * (0.9 / ne),
  xmax = cx - 0.45 + (1:ne)       * (0.9 / ne),
  ymin = cy - 0.45, ymax = cy + 0.45, ...)
geom_rect_interactive(data = franjas, aes(...), colour = NA, inherit.aes = FALSE)
```

### ⚠️ `inherit.aes = FALSE` es imprescindible

Sin él, `geom_rect` hereda el `aes(x = columna, y = fila)` global del `ggplot()` y falla
con *"objeto 'columna' no encontrado"*, porque esos datos no tienen esa columna.

### Un efecto secundario que salió gratis

Cada franja lleva el `data_id` de **su propia especie**, no del grupo. Como el cuadro de
esa especie en la fila inferior comparte ese `data_id`, **al pasar el mouse por una rayita
se resaltan los dos a la vez**: el multicolor queda conectado con la fila de abajo y
señalar una franja te dice cuál de las especies es.

El tooltip sí es común a todas las franjas y muestra el conjunto ("Todas juntas: 2.2% de
los registros"); el dato individual está en el cuadro de abajo.

**La regla se activa sola:** si un estado no tiene especies fuera (Nayarit, Colima), no
aparece el multicolor y la rejilla se dibuja como siempre.

### Un intento descartado: las raras como segunda leyenda

Antes de esto se probó moverlas a la derecha, bajo la leyenda. **Sí se puede** —mapeándolas
a `colour` en vez de `fill`, ggplot genera una segunda leyenda y la apila— pero el usuario
lo rechazó por dos razones válidas: en la fila inferior son **cuadros del mismo tamaño que
los del waffle**, así que se entienden como "lo que no alcanzó a ocupar un cuadro", y en
la leyenda se volvían llaves pequeñas que perdían esa relación. Además se perdía el
tooltip con el porcentaje exacto.

## Barra de herramientas de las gráficas

```r
opts_toolbar(saveaspng = TRUE, pngname = "altitud_global", hidden = "selection")
```

- **`hidden = "selection"`** quita los dos botones de lazo, que no se usan.
- **`saveaspng = TRUE`**: estaba en `FALSE` desde antes, así que **la descarga en PNG
  llevaba tiempo apagada** sin que nadie lo notara.
- **`pngname`** le da nombre propio al archivo de cada gráfica; sin él todas se descargan
  como `diagram.png`.

## Bug del modal de pantalla completa (ggiraph 0.9.6)

Reportado por el usuario: en Safari la figura salía diminuta dentro de una caja blanca
alta y angosta al usar pantalla completa. En Chrome y Firefox se veía bien.

**Primer diagnóstico, equivocado:** se atribuyó a la proporción de la gráfica. Al saber
que en Chrome y Firefox funcionaba, quedó descartado.

**La causa real está en el CSS que instala el paquete** (`htmlwidgets/girafe.css`):

```css
.ggiraph-fullscreen-content {
  height: 90vw;      /* vw = ANCHO de la ventana, usado como ALTO */
  max-height: 90vh;
  /* no declara ningún width */
}
```

`90vw` es casi seguro un typo por `90vh`. **Y no es exclusivo de Safari:** medido en
Chromium, el modal daba **366×648 px en una ventana de 1280×720**.

La corrección va en `www/styles.css`, que se sirve a todos los usuarios sin depender de su
navegador. Con ella el modal pasó a **1178×662 px**.

**Reportado río arriba** como bug en el repo de ggiraph. Si una versión futura lo corrige,
ese bloque de CSS se puede quitar.

## Alto de la gráfica de Floración: el piso que deformaba los cuadros

Con el filtro en *Cultivados* (5 especies) los cuadros se veían enormes; con *Silvestres*
(55) se veían normales.

La causa era `max(600, n * 28)`: ese **piso de 600 px** obligaba a la gráfica a medir 600
aunque solo hubiera 5 especies, y los cuadros se estiraban para llenarlo. Con 55 especies
el piso nunca se activaba, por eso solo se notaba en Cultivados.

```r
max(150, length(unique(FloFru1_data()$Especie)) * 28 + 70)
```

El margen del título y los dos ejes de meses va **sumado, no como mínimo**. Los 70 px se
midieron en el navegador comparando el alto del SVG contra el alto real de los cuadros.

**Verificado:** Silvestres 25.3 px por renglón, Cultivados 25.7 px. Antes eran 26 y 120.

## Tipografía: qué alcanza el CSS y qué no

El usuario pidió que la tipografía de `www/styles.css` (PT Sans para texto, Oswald para
títulos) aplicara a **toda la Shiny**, no solo a la introducción.

**Parte HTML — resuelto.** Antes todo estaba acotado a `.contenido-frijol`, porque
aplicar esas reglas a toda la app descuadraba los recuadros de Visualización. La clave
fue **separar familia de tamaño**:
- **familia tipográfica → global** (`body`, `.main-sidebar`, `.box`, `.form-control`,
  `.selectize-input`, `button`, `input`, `select`, `label`, y `h1`–`h6` + `.box-title`
  con Oswald). Es lo que da identidad visual y no rompe nada.
- **tamaños grandes → siguen acotados a `.contenido-frijol`**, que es lo que descuadraba
  el menú lateral, los controles y las cajas.

**Parte de las gráficas — NO se puede, se dejó en la fuente por defecto.** Las gráficas
son imágenes que genera R, así que el CSS no las alcanza; hay que pasarle la familia a
ggplot por separado. Se intentó:
- `Oswald` **no está instalada** en el sistema, así que ni siquiera era candidata.
- `PT Sans` **sí está instalada** (`systemfonts::system_fonts()` la ve, con sus cuatro
  variantes incluida itálica) y funciona en pruebas aisladas con `ggsave()`.
- Pero al poner `theme_minimal(base_family = "PT Sans")` en la app,
  **desaparece TODO el texto de la gráfica** — etiquetas de especies y marcas de los
  ejes incluidas (verificado renderizando el PNG). No lanza error ni warning, solo no
  dibuja texto.
- Aparte, ninguna de las dos fuentes estaría en la imagen Docker (`rocker/shiny:4.5.1`)
  del servidor, así que dependerlas sería frágil para el deploy de todos modos.

→ Las gráficas se quedan con la tipografía por defecto de ggplot, que renderiza
confiable en cualquier entorno. Queda una nota explicando esto en `global.R` para que
nadie lo vuelva a intentar sin saber el antecedente. Si algún día se quiere de verdad,
el camino sería `showtext` + `sysfonts::font_add_google()` (descarga la fuente en
tiempo de ejecución) y probarlo bien, o meter las fuentes en el Dockerfile.

### Nota sobre el navegador de pruebas automatizado

Al reiniciar la app muchas veces seguidas, el panel de navegador de pruebas se queda
en estado `recalculating` indefinidamente aunque R esté al 0% de CPU (websocket en mal
estado). No es un bug de la app. Cuando pasa, la verificación confiable es generar la
figura directamente en R (`ggsave()` a PNG) e inspeccionarla, en vez de pelear con el
navegador. Además, cambiar de pestaña con `.click()` vía JavaScript no siempre dispara
los eventos que Shiny escucha para reanudar outputs suspendidos — hay que hacer clic
real por coordenadas.

**Locale y acentos:** los scripts de prueba lanzados con `Rscript` desde la terminal
del agente corren con locale roto (`OS reports request to set locale to "" cannot be
honored`) y manglan los acentos en la salida (`É` sale como `<c3><89>`). **Eso es
artefacto del entorno de pruebas, no de la app.** Al lanzar la app con
`LANG=es_ES.UTF-8 LC_ALL=es_ES.UTF-8` los acentos salen perfectos. Si algo con acentos
"se ve mal" en una prueba de terminal, verificar en la app real antes de intentar
arreglar el código.

**Mejor alternativa: usar Google Chrome.** A sugerencia del usuario, se pasó a verificar
con las herramientas de Chrome (`mcp__claude-in-chrome__*`) en vez del panel de navegador
interno. Funciona mucho mejor: los clics reales sí registran, los desplegables de
`pickerInput` se ven en las capturas, y no se queda atorado en `recalculating`. **Usar
Chrome por defecto para verificar cambios visuales en esta app.**

## Mapa de Distribución: proveedores de tiles (`output$mymap1` en server.R)

Se reemplazaron los 3 proveedores anteriores (`addTiles()` con OSM por defecto,
`CartoDB.DarkMatter`, `OpenStreetMap.France`) por el patrón que usa el usuario en otro
proyecto CONABIO (Algodón):
```r
addProviderTiles(providers$CartoDB.Positron, group = "Mapa") %>%
addProviderTiles(providers$Esri.WorldImagery, group = "Foto aérea") %>%
...
addLayersControl(baseGroups = c("Mapa", "Foto aérea"), position = "topright",
                  options = layersControlOptions(collapsed = FALSE))
```
Se quitó la variable `baseGroups1` (ya no se usa). No se copiaron `addMapPane()` ni
`fitBounds()` del ejemplo de referencia — no fueron pedidos explícitamente y el
comportamiento de zoom/paneles de esta app no los necesitaba.

## Refactor: filtros del mapa de Distribución con shinyWidgets

El usuario es el autor original de esta app y escribió el filtrado cruzado (Condición/
Estado/Especie del mapa) como fue aprendiendo — una serie manual de 7 combinaciones
`if/else` con `updateSelectInput()` (~90 líneas en `server.R`) más un `reactive()`
aparte para filtrar los datos del mapa. Después conoció
`shinyWidgets::selectizeGroupServer()`/`selectizeGroupUI()`, que resuelve ambas cosas
de forma nativa, y pidió eficientizarlo.

**Cambios:**
- Se instaló `shinyWidgets` (0.9.1) vía `renv::install("shinyWidgets")`.
- `ui.R`: se agregó `library(shinyWidgets)`; se reemplazaron los 3 `selectInput()`
  sueltos (con sus `tags$style(make_css(...))` de color rojo por id) por un solo
  `selectizeGroupUI(id = "my_filters", params = list(Habitat.1 = ..., Estado = ...,
  Especie = ...), inline = FALSE)` dentro del mismo `absolutePanel`.
- `server.R`: se agregó `library(shinyWidgets)`; se reemplazó el `observeEvent` de
  90 líneas + el `reactive() points` manual por:
  ```r
  points <- callModule(
    module = selectizeGroupServer,
    id = "my_filters",
    data = Mex3,
    vars = c("Habitat.1", "Estado", "Especie"),
    inline = FALSE
  )
  ```
  (el `inline = FALSE` hay que ponerlo **tanto en la UI como en el server** — solo
  ponerlo en la UI causó que "Estado:" y "Especie:" se vieran apretados en la misma
  fila, porque el `inline` del server controla el CSS `display` de cada contenedor
  internamente vía `toggleDisplayServer`).
- `output$mymap1` no requirió cambios — sigue usando `points()` igual que antes, ya
  que el módulo también devuelve un reactive con el data frame ya filtrado.

**Diferencia de comportamiento:** antes cada selector tenía una opción literal `"All"`
para quitar el filtro. Con el módulo, el comportamiento nativo es limpiar/deseleccionar
el campo para ver todo sin filtrar — no hay opción "All" en la lista. Es el
comportamiento estándar del módulo, no un descuido.

**Se simplificó el estilo:** los `tags$style` que pintaban las 3 etiquetas de rojo
(`#e74c3c`) se quitaron — el módulo genera sus propios ids internos namespaced
(`my_filters-Habitat.1`, etc.) y no son triviales de re-apuntar con CSS sin inspeccionar
el DOM generado. Si se quiere recuperar ese detalle visual, sería un ajuste aparte.

**✅ Migrado a `datamods` (la deprecación quedó resuelta).** shinyWidgets avisaba que
`selectizeGroupUI`/`selectizeGroupServer` están obsoletas y las va a retirar. Se migró a
`datamods::select_group_ui()`/`select_group_server()` (1.5.3). Diferencias de la API que
hay que conocer:

| | shinyWidgets (antes) | datamods (ahora) |
|---|---|---|
| Servidor | `callModule(selectizeGroupServer, id, data, vars)` | `select_group_server(id, data_r, vars_r)` — se llama **directo**, patrón `moduleServer` |
| Argumentos | `data`, `vars` (valores) | `data_r`, `vars_r` (**reactivos**, de ahí el sufijo) |
| Etiqueta de cada filtro | aceptaba `title` o `label` | **solo `label`** |
| Botón de reinicio | `btn_label` | `btn_reset_label` |
| Widget | selectize | `virtualSelectInput` (permite selección múltiple con casillas) |
| Extra | — | `vs_args` para configurar el widget |

⚠️ **Trampa:** al migrar tal cual, los filtros salieron **sin etiqueta**, solo con un
"Select" genérico. La causa es la fila de `title` en la tabla: shinyWidgets aceptaba ese
nombre, datamods lo ignora y solo lee `label`. Se detectó al revisarlo en el navegador,
no daba error.

**Mejora de usabilidad:** el panel de filtros mide 150px y los nombres de especie salían
truncados ("Phaseolus a…"). Se resolvió ensanchando **solo el desplegable** con
`vs_args = list(search = TRUE, dropboxWidth = "320px", searchPlaceholderText = "Buscar...")`,
sin tener que ensanchar el panel. De paso quedó con buscador.

**Nota:** `shinyWidgets` sigue siendo dependencia — se usa para los `pickerInput` de las
otras pestañas (estados en Altitud, capitales, paleta del waffle). Lo único que se migró
fue el módulo de filtros cruzados.

**Verificación hecha:**
- `Rscript -e "parse('ui.R'); parse('server.R')"` sin errores.
- Se confirmó que no quedan referencias sueltas a `input$Habitat.1`/`input$Estado`/
  `input$Especie` en ningún otro lugar del código (esos ids ahora viven namespaced
  dentro del módulo).
- Se corrió la app en background (`shiny::runApp(".", port=8991)`) y se probó en un
  navegador headless: el mapa carga con todos los puntos, los 3 selectores aparecen
  correctamente etiquetados y apilados, y al abrir "Condición" muestra las opciones
  correctas (Cultivado/Escapado/Silvestre) obtenidas del servidor — confirma que el
  módulo sí está conectado a los datos reales. **No se pudo verificar de forma
  automatizada que seleccionar un valor efectivamente acote las opciones de los otros
  selectores** (limitación de la herramienta de navegador automatizado con este tipo
  de widget JS — los clicks/teclas no llegaban a registrarse en el `selectize`, no es
  un indicio de bug). Pendiente que el usuario confirme el filtrado cruzado con clicks
  normales en RStudio.

**Bug encontrado por el usuario tras probarlo en RStudio:** al seleccionar varios
valores en "Estado", las etiquetas se iban extendiendo hacia la derecha en vez de
apilarse hacia abajo — el `absolutePanel` nunca tuvo un ancho fijo (antes cada
`selectInput` individual sí tenía `width = 200`, pero el panel contenedor no), así
que crecía con el contenido en vez de forzar el wrap.
→ Se agregó `width = 280` al `absolutePanel` en `ui.R`, más una regla CSS de respaldo
en `styles.css`:
```css
#controls .selectize-input {
  flex-wrap: wrap;
  height: auto;
  max-width: 100%;
}
```
