FROM rocker/shiny:4.5.1

COPY --chmod=755 ./scripts/install_reqs.sh /rocker_scripts/install_reqs.sh
RUN /rocker_scripts/install_reqs.sh

COPY . /srv/shiny-server/
