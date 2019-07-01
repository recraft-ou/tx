Client for diffing data (JSON from API vs db)
================
2019-07-01

We have two data sources that needs diffing:

1.  REST API providing transactions data in JSON format
2.  A database providing transactions data that differs slightly

What differs? We would like to diff the two sources for a report.

## Data from first source

``` r
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
```

| field         | value                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| :------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| amount        | 0.9808879                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| confirmations | 6698                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| blockhash     | 8d258a85b4a17b43a367532336ba4ea93530d97a1da8a14465ada34014e1307c                                                                                                                                                                                                                                                                                                                                                                                                     |
| blockindex    | 2                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| blocktime     | 2017-02-10 13:06:57                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| txid          | 2147e612b53006d659d12b760775355de90634266275525da04e5d4710e2301a                                                                                                                                                                                                                                                                                                                                                                                                     |
| time          | 2017-07-23 18:08:20                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| timereceived  | 2017-07-23 17:08:20                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| account       |                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| address       | mhb48fBqU5JtwKuKhvqF3XyGT1FCZ8VY2y                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| category      | receive                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| hex           | 93b38d74b31169d512d072570848b00a2814810e2817743e46ae26737a233619908575d13218cd0c8bdbcb71000a2dab455519cd13e052e2432625b407a1840c430a63a049ada49cbc7b06cdc754632a0e41b3627c78e73aa92c910ad9d61787817ada461a220e4ab96b3c5dd90d2ba989cc65cd5b4c00b6b4b70cb657d4ae0aa138137ea57d914aaba10635067d3128bdc2bccb08be4609b8710e35ed7ab1a8b7c1c490879513c467cc12351b9256771739e6c70c65929d116e842b930b77c41098cc7ae00590c124a154badc7a22b870654651762b633651c09a63d0e0aaa442b3 |

## Data from database source

Since we now have data form the API source in JSON, we proceed to get
data from the mysql db to compare it with. To do this we create a
database connection (defined in config.yml with credentials from
environment vars) and get the relevant data from the database

``` r
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
```

Now we can diff the two data sources. If the data was big enough not to
fit in memory, we’d use Apache Spark or Apache Drill instead. The
tidyverse and dplyr APIs can be used with these datasources too. It is
of course possible to use regular database specific sql statements too
if that is a preference, but I prefer the tidyverse and dplyr tools for
data wrangling tasks. For diffing datasets, there is for example
`anti_join()` and `setdiff` which these operations conveniently compared
to sql, in my opinion.

``` r
# compare the data from the API with the data from the db
# since the db table has two additional columns, we exclude these

df_left <- df  # from API
df_right <- df_db %>% select(-c(amount_changed, is_changed))  # from db

diff_left <- setdiff(df_left, df_right)
diff_right <- setdiff(df_right, df_left)


# these are records that don't match between the two sources
knitr::kable(diff_left %>% select(txid))
```

| txid                                                             |
| :--------------------------------------------------------------- |
| 43708404ce691950b4d80346289a72556242cdda97c909285abded3a9cb362ac |
| 32c3b07c488803ab0743424e99b803b31e6382e9a348cabd71ac545aa48e5552 |
| e27695404111cc00c996840d2b70c7b4b7c7a10130949ba9c3a7550c02a86980 |
| 621430b6eea82d82412bd1b4390a0b7a7531457708dc82265903cc9582984505 |
| 4005d75c9c3a114763bad826dc05b6d59419c03e16dcbb2890d63840228b2b26 |
| 12419d5aaa7c0b04d31d610ae43765212522a9a4c34ac7e61e1c65ee212ba031 |
| c3497821be84151c975c03ab45485c000b017a3e7262be5e149d9b84aa204490 |
| 8815aeac007c95b43aae94eb734967c156440140064a1d2a98a52a5ea124e235 |
| 0881b1374207b529303a378250c269050d616d001dcce744e6001553b876620b |
| 4512816e279c833c953d1b1c4117883a9b5b07de9b03a74e3dc17185e6990e62 |

If there are many fields that differ for these transactions we’d like to
know which ones those are, here we suspect the amounts will differ
(because that is how our synthetic data looks like) but if we didn’t
know that, how could we find which fields differ within the records?

``` r
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
```

These fields for records that show a diff, assuming txid is a relevant
identifier

``` r
double_check <- 
  diff_left %>% 
  select(txid) %>% 
  bind_cols(fields_left, fields_right)
  
knitr::kable(double_check)
```

| txid                                                             |    amount |   amount1 |
| :--------------------------------------------------------------- | --------: | --------: |
| 43708404ce691950b4d80346289a72556242cdda97c909285abded3a9cb362ac | 0.4450567 | 0.4234152 |
| 32c3b07c488803ab0743424e99b803b31e6382e9a348cabd71ac545aa48e5552 | 0.9561037 | 0.9096119 |
| e27695404111cc00c996840d2b70c7b4b7c7a10130949ba9c3a7550c02a86980 | 0.2792622 | 0.2656827 |
| 621430b6eea82d82412bd1b4390a0b7a7531457708dc82265903cc9582984505 | 0.7569548 | 0.7201469 |
| 4005d75c9c3a114763bad826dc05b6d59419c03e16dcbb2890d63840228b2b26 | 0.4580932 | 0.4358178 |
| 12419d5aaa7c0b04d31d610ae43765212522a9a4c34ac7e61e1c65ee212ba031 | 0.8871091 | 0.8439722 |
| c3497821be84151c975c03ab45485c000b017a3e7262be5e149d9b84aa204490 | 0.7303667 | 0.6948517 |
| 8815aeac007c95b43aae94eb734967c156440140064a1d2a98a52a5ea124e235 | 0.6109147 | 0.5812082 |
| 0881b1374207b529303a378250c269050d616d001dcce744e6001553b876620b | 0.4453037 | 0.4236502 |
| 4512816e279c833c953d1b1c4117883a9b5b07de9b03a74e3dc17185e6990e62 | 0.6679629 | 0.6354823 |
