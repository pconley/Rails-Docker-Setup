# Rails in Docker

Build a simple rails application in two docker images... one for the db and one for the app.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

Assumes that Docker is already installed.
Does *not* require rails to be installed.
All my work/testing was don on a Mac.

## Clean up from any previous attempts

### Stop and Remove Containers
```
docker ps -a                    # see all containers
docker stop $(docker ps -a -q)  # stop all containers
docker rm $(docker ps -a -q)    # remove all containers
```
### Delete all images if you want a complete restart
```
docker images                   # list of all images
docker rmi $(docker images -q)  # CAUTION: removes ALL images ever built
```
# Step 1

Run the standard ruby image as a temporary container linked to the 
current directory. We just to use it to create the rails app.
Params are... remove after run; interactive; map a volume; open bash

```
docker run --rm -it -v "$PWD:/app" ruby:2.3 bash
```

We are now in bash in the running container; so we
create a rails app from scratch with postgres

```
cd app
gem install rails
rails new example -d postgresql --skip-bundle
cd example
ls -la
exit 
```
We are back on the host machine (mac).
A blank, example rails app was created. Now we can
edit the rails files directly from the mac in the shared 
volume directory.

```
cd example
```

Copy 5 files from the repo to the example directory

1. Dockerfile (defines the image)
2. Gemfile (to include ruby racer)
3. config/database.yml (for postgres setup)
4. env_setting file (to match database.yml)
-. Note that the secrets.yml file also expects an environment variable
-. alter that string in the env_settings file
5. docker-compose.yml (for a later step) 

```
docker build -t example_tag .       # build the docker image tagged "example_tag"
docker images                       # see all the images... now including this one
```
A "network" is the docker mechanism to communicate bewteen our two running container.  
Delete the "example_net" network if already exists (from a previous attempt).
```
docker network ls               # see all networks
docker network rm blog_net      # remove if it exists
docker network create blog_net  # and create a new one
```

We need to be sure that the same values are used in the app and the db
so use environment variable to set these vaules.
```
cat env_settings                # to see the environment variables
. env_settings                  # set the environment variables
echo $POSTGRES_USER             # check that they are set
```

### Run the containers

(manually) run a container from the standard postgres image
but makes use of the environment variables we set; note that
we use the network we just created; and give it a name "db"

docker run -d \
    -e POSTGRES_USER=$POSTGRES_USER \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
    --net=talker_net --name db \
    postgres

now run the app in a container that is interactive

docker run --rm -it \
    -v "$PWD:/usr/src/app" \
    -p 3000:3000 \
    -e POSTGRES_HOST=$POSTGRES_HOST \
    -e POSTGRES_USER=$POSTGRES_USER \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
    --net=talker_net --name app \
    talker_tag bash

# we are now inside the rails app container

rake db:setup db:migrate        # create the database
rails s                         # run server; go to localhost:3000

ctl-c                           # kill the server

rails generate scaffold Post name:string title:string body:text
rake db:migrate
# note we can edit routes from the mac to add a new root to: "posts#index"
rails s

# create a post via the browser (to see if it persists later)

ctl-c   # kill the server
exit    # back on the mac 

# now run the same app as a deamon; note that the dockerfile
# automatically starts the rails server

docker run -d \
    -p 3000:3000 \
    -e POSTGRES_HOST=$POSTGRES_HOST \
    -e POSTGRES_USER=$POSTGRES_USER \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
    --net=blog_net --name app \
    -v $PWD:/usr/src/app \
    blog_tag

# shut down all the containers...
docker ps -a                    # see all containers
docker stop $(docker ps -a -q)  # stop all containers
docker rm $(docker ps -a -q)    # remove all containers

################################################################
# Docker Compose uses the docker-compose.yml file to 
# automate all the complex commands
################################################################

docker-compose build                    # creates container with default name

docker images                           # of example_app

docker-compose run app rake db:setup db:migrate   # runs app container with a command

docker ps -a                            # note that the DB also ran and continues

docker-compose stop                     # so lets stop it

docker-compose up                       # start both
docker-compose ps                       # see the list
docker-compose stop                     # from another tab?

docker ps -a                    # see all containers
docker stop $(docker ps -a -q)  # stop all containers
docker rm $(docker ps -a -q)    # remove all containers

docker-compose up -d                    # deamonize
docker-compose stop                     # to stop deamon(s)
docker ps                               # but they are still there

#########################################################################################
# use Docker Machine to manage virtual machines on which 
# we will deploy the containers; this walkthru uses DigitalOcean
# to host one machine... puts the two containers on that machine
# note: a DO account and access key was previously created!!!!
#########################################################################################

# first clean up any previous walthru attemps

docker-machine ls
docker-machine kill xxxxx               # stops the machine by name
docker-machine rm xxxxx                 # WARNING: removes from cloud

# create a machine named blogmachine (called a droplet on DO)

docker-machine create \
    --driver=digitalocean \
    --digitalocean-access-token=f4fb54e51f72f0477732ea68e2a66139083041a0bbc97739b9570c88be3d8677 \
    --digitalocean-size=1gb blogmachine

# the machine is now visible on the DO site

# as described in the output... connect docker client to the new machine
# executint the output of the next command which will set env variables

docker-machine env blogmachine

# start the database container 
docker-compose -f docker-compose.prod.yml up -d db

# build the app container
docker-compose -f docker-compose.prod.yml build app

# ONE TIME run the app container to buid the database
docker-compose -f docker-compose.prod.yml run --rm app rake db:create db:migrate

# run the app container (in the foreground)
docker-compose -f docker-compose.prod.yml up app

# stop both containers
docker-compose stop

# start the app which also starts the db dependecy (as a deamon)
docker-compose -f docker-compose.prod.yml up -d

# now we could walk away and leave it running in the cloud!
