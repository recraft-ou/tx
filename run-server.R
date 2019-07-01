source("tx-server.R")
#pr$mount("/__swagger__", PlumberStatic$new(swagger::swagger_path()))
pr$run(host = "0.0.0.0", port = 9090, swagger = TRUE)
#browseURL("http://127.0.0.1:9090/__swagger__/")

