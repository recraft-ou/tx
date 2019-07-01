#! make

PWD := $(shell pwd)
UID := $(shell id -u)
GID := $(shell id -g)

all: build up

build:
	# uses debian-based rocker/geospatial:3.6.0 but extends it with 
	# various system libraries and R packages
	docker build -t mskyttner/tx:3.6.0 .
	
up:
	docker run --name goobitdb \
		-e MYSQL_ROOT_PASSWORD=password12 \
    -e MYSQL_USER=goobit \
    -e MYSQL_PASSWORD=qwerty \
    -e MYSQL_DATABASE=transactions \
    -p "3306:3306" \
    -h goobitdb \
    -d mysql:5.7.26 \
    --character-set-server=utf8mb4 \
    --collation-server=utf8mb4_unicode_ci \
    --max_allowed_packet=1073741824

	docker run --name tx \
		-d -p 8787:8787 \
		-e PASSWORD=tx -e USERID=$(UID) -e GROUPID=$(GID) \
		-v "$(PWD):/home/rstudio" mskyttner/tx:3.6.0 /init
		
	echo "Use rstudio/tx to login!"; sleep 3;
	firefox localhost:8787 &

clean: clean-docker

clean-docker:
	docker stop tx goobitdb
	docker rm -vf tx goobitdb
	
release:
	docker login
	docker push mskyttner/tx:3.6.0
