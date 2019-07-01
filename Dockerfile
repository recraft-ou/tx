FROM rocker/geospatial:3.6.0

# the layer above is based on Debian

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  pdftk \
  libpoppler-cpp-dev \
  libgsl0-dev \
  libsodium-dev
  
RUN install2.r --error \
  magick \
  staplr \
  pdftools \
  printr \
  officer \
  available \
  googledrive \
  here

# more CRAN packages installation

RUN install2.r --error \
  DT \
  flexdashboard \
  rsvg \
  RMariaDB \
  config \
  bcrypt \
  swagger

RUN installGithub.r --deps TRUE \
	jandix/sealr

# workaround for devtools > 2.0

#RUN sudo -u rstudio R -e "library(devtools); install_github('jandix/sealr')" #, dependencies = TRUE, build = TRUE, build_opts = c('--no-resave-data', '--no-manual'))"

