#' ---
#' title: "Client for diffing data (JSON from API vs db)"
#' author: ""
#' output: 
#'  github_document
#' ---

#' We have two data sources that needs diffing:
#' 
#' 1. REST API providing transactions data in JSON format
#' 1. A database providing transactions data that differs slightly
#' 
#' What differs? We would like to diff the two sources for a report.
#' 
#' ## Data from first source

library(httr)
library(dplyr)
library(tibble)
library(purrr)

auth <- POST(
  encode = "json",
  url = "http://localhost:9090", 
  path = "authentication", 
  body = list(user = "johan", password = "password12")
)
  
if (status_code(auth) != 200)
  stop("Authentication failed")
  
token <- content(auth)[[1]]

txs <- GET(add_headers(Authorization = paste("Bearer", token)),
    url = "http://localhost:9090",
    path = "transactions")

as_txrecord <- function(x) {
  # fcn to adjust for type loss when round-tripping 
  # typed (data.frame/tibble) nested record over json
  x$details <- map(x$details, as_tibble) %>% pluck(1)
  x
}

# we retrieve all JSON from the authed API endpoint
# flatten the nested JSON and convert it into tabular 
# data, also we convert nix epoch timestamps to datetimes

df <- 
  content(txs) %>% 
  map(as_txrecord) %>%
  map_df(purrr::flatten) %>% 
  mutate_at(vars(blocktime, time, timereceived), list(lubridate::as_datetime))

# we now glimpse a single record from the API

vertical <- 
  df %>% slice(1) %>% t() %>% as.vector() %>% tibble() %>% 
  mutate(field = names(df)) %>% 
  select(field, value = 1)

knitr::kable(vertical)


#' ## Data from database source
#' 
#' Since we now have data form the API source in JSON, we proceed to get
#' data from the mysql db to compare it with. To do this we create a database
#' connection (defined in config.yml with credentials from environment vars)
#' and get the relevant data from the database

library(RMariaDB)
library(config)

# if running for the first time, do this to get config.yml in the right location
#dir.create(rappdirs::app_dir("goobit")$config(), recursive = TRUE)
#file.copy("config.yml", rappdirs::app_dir("goobit")$config())

cfgfile <- file.path(rappdirs::app_dir("goobit")$config(), "config.yml")
cfgfile <- normalizePath(cfgfile)
config <- config::get(NULL, "goobit", file = cfgfile)

# do this to edit the db connection credentials/details configs
#file.edit(cfgfile)
#file.edit("~/.Renviron")

readRenviron("~/.Renviron")

con <- DBI::dbConnect(
  RMariaDB::MariaDB(),
  #  RMySQL::MySQL(max.con = 256), 
  host = config$goobit$server,
  username = config$goobit$dbuser,
  password = config$goobit$dbpass,
  dbname = config$goobit$database,
  timeout = 60,
  port = 3306
)


df_db <- con %>% tbl("transactions") %>% collect()

dbDisconnect(con)

#' Now we can diff the two data sources. If the data was big enough
#' not to fit in memory, we'd use Apache Spark or Apache Drill instead.
#' The tidyverse and dplyr APIs can be used with these datasources too.
#' It is of course possible to use regular database specific sql statements
#' too if that is a preference, but I prefer the tidyverse and dplyr tools
#' for data wrangling tasks. For diffing datasets, there is for example `anti_join()`
#' and `setdiff` which these operations conveniently compared to sql, in my opinion.

# compare the data from the API with the data from the db
# since the db table has two additional columns, we exclude these

df_left <- df  # from API
df_right <- df_db %>% select(-c(amount_changed, is_changed))  # from db

diff_left <- setdiff(df_left, df_right)
diff_right <- setdiff(df_right, df_left)


# these are records that don't match between the two sources
knitr::kable(diff_left %>% select(txid))

#' If there are many fields that differ for these transactions
#' we'd like to know which ones those are, here we suspect
#' the amounts will differ (because that is how our synthetic data looks like)
#' but if we didn't know that, how could we find which 
#' fields differ within the records?

fields_left <- 
  map2(diff_left, diff_right, function(x, y) setdiff(x, y)) %>%
  map(function(x) if(length(x) < 1) NA else x) %>% 
  as_tibble() %>%
  select_if(function(x) !all(is.na(x)))

fields_right <- 
  map2(diff_right, diff_left, function(x, y) setdiff(x, y)) %>%
  map(function(x) if(length(x) < 1) NA else x) %>% 
  as_tibble() %>%
  select_if(function(x) !all(is.na(x)))

#' These fields for records that show a diff, assuming txid is
#' a relevant identifier

double_check <- 
  diff_left %>% 
  select(txid) %>% 
  bind_cols(fields_left, fields_right)
  
knitr::kable(double_check)

