#!/bin/bash

set -e

## build ARGs
NCPUS=${NCPUS:--1}

# a function to install apt packages only if they are not installed
function apt_install() {
    if ! dpkg -s "$@" >/dev/null 2>&1; then
        if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
            apt-get update
        fi
        apt-get install -y --no-install-recommends "$@"
    fi
}

apt_install \
    libicu-dev \
    libjpeg-dev \
    libpng-dev \
    libharfbuzz-dev \
    libglpk-dev \
    libxml2-dev \
    libproj-dev \
    libgdal-dev \
    libgeos-dev \
    libudunits2-dev

install2.r --error --skipinstalled -n "$NCPUS" \
    ash \
    colorspace \
    datamods \
    DT \
    RColorBrewer \
    ggmap \
    ggthemes \
    ggiraph \
    ggrepel \
    gridExtra \
    extrafont \
    igraph \
    latticeExtra \
    leaflet \
    maps \
    markdown \
    plotly \
    plyr \
    proj4 \
    sf \
    shiny \
    shinydashboard \
    shinydashboardPlus \
    shinyjs \
    shinyWidgets \
    sp \
    tableHTML \
    tidyverse \
    vegan \
    wesanderson

install2.r --error --skipinstalled -r NULL -t "source" "https://cran.r-project.org/src/contrib/Archive/ggalt/ggalt_0.4.0.tar.gz"

install2.r --error --skipinstalled -r NULL -t "source" "https://cran.r-project.org/src/contrib/Archive/waffle/waffle_1.0.2.tar.gz"

## a bridge to far? -- brings in another 60 packages
# install2.r --error --skipinstalled -n "$NCPUS" tidymodels

# Clean up
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/downloaded_packages

## Strip binary installed lybraries from RSPM
## https://github.com/rocker-org/rocker-versioned2/issues/340
strip /usr/local/lib/R/site-library/*/libs/*.so

# Check the igraph version
echo -e "Check the igraph package...\n"

R -q -e "library(igraph)"

echo -e "\nInstall igraph package, done!"

# Check the ggalt version
echo -e "Check the ggalt package...\n"

R -q -e "library(ggalt)"

echo -e "\nInstall ggalt package, done!"

# Check the waffle version
echo -e "Check the waffle package...\n"

R -q -e "library(waffle)"

echo -e "\nInstall waffle package, done!"

# Check the waffle version
echo -e "Check the datamods package...\n"

R -q -e "library(datamods)"

echo -e "\nInstall datamods package, done!"

# sf necesita GDAL/GEOS/PROJ del sistema y truena en tiempo de carga si falta
# alguno, no al instalarse. Se comprueba aqui para que la imagen falle al
# construirse y no en el arranque de la app.
echo -e "Check the sf package...\n"

R -q -e "library(sf)"

echo -e "\nInstall sf package, done!"
