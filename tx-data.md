Synthetic data for tx diff demo
================
2019-07-01

We need three example datasets for the demo

  - JSON for transactions given by a REST API with jwt auth
  - A user database for authenticating users against the API
  - A relational db with slightly different transactions data In order
    to implement a demo REST server with JSON Web Tokens (jwt)
    authentication that delivers “transactions data”, we need some
    example data structure. We find an example of mildly nested JSON
    that describes transactions at GitHub and will use that in the
    example

<!-- end list -->

``` r
library(jsonlite)
library(tibble)
library(dplyr)
library(tidyr)
library(purrr)

# inspect the JSON data
url <- paste0(
  "https://raw.githubusercontent.com/johan-karlsson-goobit-se/",
  "BTCX_blockchain/master/examples/transactionWithtxid.txt"
)

tx <- fromJSON(readr::read_lines(url, n_max = 21))

# assume depth one for boxed values
record <- tx %>% purrr::flatten() %>% map_df(1)

# print one example record in tabular flattened format
vertical <- 
  record %>% t() %>% as.vector() %>% tibble() %>% 
  mutate(field = names(record)) %>% 
  select(field, value = 1)

knitr::kable(vertical)
```

| field         | value                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| :------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| amount        | 1.5                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| confirmations | 119                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| blockhash     | 0000000079977db7ae994969e70f209dbdeb216d72927ee6baa28300f5e91ebb                                                                                                                                                                                                                                                                                                                                                                                                     |
| blockindex    | 2                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| blocktime     | 1402530120                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| txid          | 976476eba723c594f945308abfcbf3216534d0c10e6854bec6d47f5208e256f5                                                                                                                                                                                                                                                                                                                                                                                                     |
| time          | 1402526892                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| timereceived  | 1402526892                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| account       |                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| address       | mhb48fBqU5JtwKuKhvqF3XyGT1FCZ8VY2y                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| category      | receive                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| hex           | 0100000001bf575ca3d14e50111b5060826aff43ab99e1c4f3ad0b96c6f230cba564bde668000000006b483045022100ba9198092f8ac3a9224dea31528bfc7237cc6842e22bea7c7375613021cbdccc02205430c7cf70ad67fd288602dd5fa037da8d61759ce7fc57308ab6f39e42943fc7012103ba6f96eeda2aaffab8ad3dab9b606efb580a4551ec9120a8b507efa938053ffaffffffff0280d1f008000000001976a91416b6c9eb711e3edc6f18af4a89b742930fe6976888ac007caf7b030000001976a914f3c4d14785de23b18a348300b144a02dd7c1f06288ac00000000 |

Now that we know how to create an example record, we can create a
function that generates similar such synthetic records. It will not
offer realistic data but data types will be similar so the payloads will
work for the example

``` r
# proceed to create a function that creates synthetic similar records
synthetic_tx <- function() {
  
  # the purpose is just to generate synthetic data records which can be used when
  # providing an example JWT-authenticated API endpoint that serves JSON in a
  # format similar to that in 
  # https://github.com/johan-karlsson-goobit-se/BTCX_blockchain/blob/master/examples/transactionWithtxid.txt
  
  # I do not know much about the distributions, so using naive approaches below
  # probably not giving very realistic data, but this is just a demo
  
  # simulates a length 64 string of hex, we pretend it is a hash
  hash_n <- function(n = 64) 
    unlist(strsplit("01234567890abcdef", ""))[floor(runif(n, 1, 16) + 0.5)] %>%
    paste(collapse = "")
  
  # simulates a unix epoch timestamp, using samples of individual UTC time components
  ts_n <- function(n = 1) paste0(
    sample(2016:2019, n, replace = TRUE), "-",
    sprintf("%02i", sample(1:12, n, replace = TRUE)), "-",
    sprintf("%02i", sample(1:27, n, replace = TRUE)), " ",
    sprintf("%02i", sample(0:23, n, replace = TRUE)), ":",
    sprintf("%02i", sample(0:59, n, replace = TRUE)), ":",
    sprintf("%02i", sample(0:59, n, replace = TRUE)), " UTC"
  ) %>% lubridate::as_datetime() %>% as.numeric()
  
  n <- 1 # we just need one sample and will vectorize using a fcn wrapper
  
  # simulate synthetic fields
  amount <- round(as.double(runif(n)), 12)
  confirmations <- ceiling(runif(n, 1, 10000))
  blockhash <- purrr::map_chr(1:n, function(x) hash_n(64))
  blockindex <- 2
  blocktime <- ts_n(n)
  txid <- purrr::map_chr(1:n, function(x) hash_n(64))
  walletconflicts <- rep(list(), n)
  time <- purrr::map_dbl(1:n, function(x) ts_n(1))
  timereceived <- time - 3600
  
  # the nested details data, we're a bit lazy here
  details <- tibble(
    account = "", 
    address = "mhb48fBqU5JtwKuKhvqF3XyGT1FCZ8VY2y", 
    category = "receive", 
    amount = amount)
  
  hex <- purrr::map_chr(1:n, function(x) hash_n(452))
  
  # we assemble this data into a record
  # we could type the dates/times but unix epoch timestamps seems to be used
  record <- list(
    amount = amount,
    confirmations = as.integer(confirmations),
    blockhash = blockhash,
    blockindex = as.integer(blockindex),
    blocktime = as.integer(blocktime),
    txid = txid,
    walletconflicts = walletconflicts,
    time = as.integer(time),
    timereceived = as.integer(timereceived),
    details = details,
    hex = hex
  )
  
  return (record)
  
}
```

In order to generate any number of synthetic transaction records we
create a function that can give n samples of records, by default 1k
records

``` r
# this function gives us by default 1000 samples of such synthetic records
synthetic_txs <- function(n = 1000) {
  N_MAX <- (1e6 - 1)
  if (n > N_MAX) stop("too large sample, use lower n")
  if (n < 0) stop("sample size needs to be larger than zero")
  purrr::map(1:n, function(x) synthetic_tx())
}

# generate a 1000 records
txs <- synthetic_txs()

# this would give us almost a million records
#txs <- synthetic_txs(n = 1e6 - 1)
```

Now we serialize these 1k synthetic records to disk so it can be used as
example data when served by the API

``` r
saveRDS(txs, "txs.rda")

# verify that roundtrip from serialized data works
#identical(txs, readRDS("txs.rda"))
```

Since we want to allow only JWT authenticated users to access the
/transactions endpoint on our demo API, we need user db which is
generated and save this using columnar storage on-disk w some made up
usernames and hashed pwds

``` r
users <- bind_rows(
  tibble(
    id = 1, user = "johan",
    password = bcrypt::hashpw("password12")
  ), 
  tibble(
    id = 2, user = "emil",
    password = bcrypt::hashpw("letmein")
  )
)

saveRDS(users, "userdb.rda")
```

The final dataset we need is data stored in a mysql database which will
need to differ a little bit so we can generate a diff with just the
records that differ

``` r
# get synthetic transactions data
txs <- readRDS("txs.rda")

# we make some small changes to the amounts for a subset of the records
# and convert epochs to datetimes and add a couple of columns
maria <- 
  map_df(txs, purrr::flatten) %>% 
  mutate_at(vars(blocktime, time, timereceived), list(lubridate::as_datetime)) %>%
  mutate(amount_changed = if_else(confirmations > 100, amount, amount * (1.05 - 0.1 * runif(1)))) %>%
  mutate(is_changed = amount != amount_changed) %>%
  mutate(amount = if_else(is_changed, amount_changed, amount))

# we store the data in a mysql db and use a config.yml file to
# configure the connection to the db
library(RMariaDB)
library(config)

#dir.create(rappdirs::app_dir("goobit")$config(), recursive = TRUE)
#file.copy("config.yml", rappdirs::app_dir("goobit")$config())

cfgfile <- file.path(rappdirs::app_dir("goobit")$config(), "config.yml")
cfgfile <- normalizePath(cfgfile)
config <- config::get(NULL, "goobit", file = cfgfile)

#file.edit(cfgfile)

# we don't store the credentials in the config.yml file
# instead we use environment variables references from there

#file.edit("~/.Renviron")
readRenviron("~/.Renviron")

con <- DBI::dbConnect(
  RMariaDB::MariaDB(),
  host = config$goobit$server,
  username = config$goobit$dbuser,
  password = config$goobit$dbpass,
  dbname = config$goobit$database,
  timeout = 60,
  port = 3306
)

# add a table with the slightly different
# transactions data to the db

if (dbExistsTable(con, "transactions"))
  dbRemoveTable(con, "transactions")

#mini <- maria %>% slice(1:1000)

copy_to(con, maria, "transactions", 
  temporary = FALSE, overwrite = TRUE
)

dbDisconnect(con)
```
