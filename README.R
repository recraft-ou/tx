#' ---
#' title: "Demo - diffing transactions (JSON from API vs db)"
#' author: ""
#' output: 
#'  github_document
#' ---

#' ## Intro
#' 
#' This repo contains a simplistic system that demos one approach for diffing transactions data from two different sources a) a Web API and b) a relational database.
#' 
#' Files:
#' 
#' - __tx-data.R__ - synthesizes example "transactions data"; generates txs.rda and userdb.rda (details below)
#' - txs.rda - serialized transactions data saved using columnar storage for use by the API
#' - userdb.rda - db for authorized users that can authenticate against the API to get transactions data
#' 
#' - __tx-server.R__ - a simple API server with JSON Web Tokens auth for serving transactions data
#' - run-server.R - script to run the API server
#' 
#' - __tx-client.R__ - a simple client for diffing transactions data from the two sources a) API and b) database
#' - config.yml - configures the database connection
#' - .Renviron - holds environment variables for credentials to db
#' 
#' - __Dockerfile__ - defines a web-based platform for data science work (Debian-based) - can develop/use/deploy the assets above
#' - __Makefile__ - various targets providing shortcuts for wiring things together and using the system
#'
#' ## Usage
#'   
#' By using the `Makefile`, the system can be built and launched using `make` and removed with `make clean`.
#' 
#' Launching the system provides browser access at http://localhost:8787 for the system.
#' 
#' ## Code
#' 
#' Source code with comments/explanations:
#' 
#' - [data wrangling](tx-data.md)
#' - [API server](tx-server.md)
#' - [diff client](tx-client.md)
#' 
#' ## Results
#' 
#' The [diff client](tx-client.md) link shows all individual steps and final diff report for the synthetic data, including a list of records that differ with only the relevant fields, that would need to be double-checked, or further processed in some automatic or manual way, I assume. 
#' 
#' ## Notes
#' 
#' This is a bare bones demo and not a fully fledged R library/package, while being simplistic it can still do some nice things:
#' 
#' - a system that can be deployed to the cloud or run locally
#' - tries to sample/synthesize any number of transactions data based on a couple of example JSON payloads
#' - shows diffing of data from API versus database giving a report of differences
#' - the API can be authed and used from any language and works with curl at the CLI
#' - the `json_tsv` functionality could be broken out into a tool that can be used from the CLI
#' - the diff report and/or related visuals could be served from API endpoints, generated at the CLI or used from within the data science platform docker container
#' - lacks a `docker-compose.yml` file which could be added for scaling up and cloud deployments, see `docker-compose.yml` file from [here](https://github.com/mskyttner/specify-docker), which uses letsencrypt for SSL/TLS certs
#'
#' Note that the synthesized data uses a fairly naive approach, as I'm learning about blockchain and lacks deeper domain expertise for this kind of data.
#' 
#' I hope the use case is fairly realistic at some level. 
#' 
#' The diff method can be extended and changed easily. 
