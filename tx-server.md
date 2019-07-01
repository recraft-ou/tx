Minimalistic REST API for synthetic transactions
================
2019-07-01

This REST API offers JSON Web Token authentication for an endpoint that
servers up JSON data for transactions

``` r
library(sealr)
```

    ## 
    ## Attaching package: 'sealr'

    ## The following object is masked from 'package:httr':
    ## 
    ##     authenticate

``` r
library(plumber)
library(httr)
library(jose)
```

    ## Loading required package: openssl

``` r
library(jsonlite)

# read userdb data to use for authentication
users <- readRDS("userdb.rda")

pr <- plumber::plumber$new()

# the APIs super secret, we could get this from an env variable
secret <- "3ec9aaf4a744f833e98c954365892583"

# filter all requests to the API for auth
pr$filter("sealr-jwt", function (req, res) {
  # integrate jwt strategy in a filter
  sealr::authenticate(
    req = req, res = res, is_authed_fun = sealr::is_authed_jwt,
    token_location = "header", secret = secret
  )
})

pr$handle("POST", "/authentication", function (req, res, user = NULL, password = NULL) {
  # define authentication route to issue web tokens (exclude "sealr-jwt" filter using preempt)
  
  if (is.null(user) || is.null(password)) {
    res$status <- 404
    return (list(
      status = "Failed.",
      code = 404,
      message = "Please return password or username."
    ))
  }
  
  index <- match(user, users$user)
  
  if (is.na(index)) {
    res$status <- 401
    return(list(
      status = "Failed.",
      code = 401,
      message = "User or password wrong."
    ))
  }
  
  if (!bcrypt::checkpw(password, users$password[index])){
    res$status <- 401
    return(list(
      status = "Failed.",
      code = 401,
      message = "User or password wrong."
    ))
  }
  
  # jwt payload; information about the additional fields at
  # https://tools.ietf.org/html/rfc7519#section-4.1
  payload <- jose::jwt_claim(userID = users$id[index])
  secret_raw <- charToRaw(secret)
  jwt <- jose::jwt_encode_hmac(payload, secret = secret_raw)
  return(jwt = jwt)
}, preempt = c("sealr-jwt"))

# create custom serializer so we can use 12 digits precision for doubles
serializer_json2 <- function (...) 
{
  function(val, req, res, errorHandler) {
    tryCatch({
      json <- jsonlite::toJSON(val, ...)
      res$setHeader("Content-Type", "application/json")
      res$body <- json
      return(res$toResponse())
    }, error = function(e) {
      errorHandler(req, res, e)
    })
  }
}

pr$handle("GET", "/transactions", function (req, res) {
  # main authenticated route where we return transactions data
  readRDS("txs.rda")
}, serializer = serializer_json2(auto_unbox = TRUE, digits = 12))
```
