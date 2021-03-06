# Rails in Docker (Work in Progress)
Build a simple rails application in two docker images... one for the db and one for the app.
## Getting Started
These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.
### To Do
- stop publishing the DO information
### Prerequisites
Assumes that Docker is already installed.
Does *not* require rails to be installed.
All my work/testing was don on a Mac.
Digital Ocean...
### Download the File
To you working directory
```
git clone https://github.com/pconley/Rails-Docker-Setup.git
```
### Stop and Remove Containers
Clean up running containers from any previous attempts.
```
docker ps -a                    # see all containers
docker stop $(docker ps -a -q)  # stop all containers
docker rm $(docker ps -a -q)    # remove all containers
```
### Remove Previous Images
This deletes any images from a previous run through.  
```
docker images               # list of all images
docker rmi example_tag      # remove provious images
```
## Step 1: Create the App
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

Copy files from the repo to the example directory

```
cp Rails-Docker-Setup/Dockerfile example
cp Rails-Docker-Setup/env_settings example
cp Rails-Docker-Setup/docker-compose.yml example
cp Rails-Docker-Setup/database.yml example/config

cd example
```
Edit the Gemfile to uncomment out the 'therubyracer' gem
```
vi Gemfile # or your favorite edito
```
Now build the docker image
```
docker build -t example_tag .       # build the docker image tagged "example_tag"
docker images                       # see all the images... now including this one
```
A "network" is the docker mechanism to communicate bewteen our two running container.  
Delete the "example_net" network if already exists (from a previous attempt).
```
docker network ls                  # see all networks
docker network rm example_net      # remove if it exists
docker network create example_net  # and create a new one
```
We need to be sure that the same values are used in the app and the db
so use environment variable to set these vaules.  Note that the env_settings 
is also used in the docker file.
```
cat env_settings                # to see the environment variables
. env_settings                  # set the environment variables
echo $POSTGRES_USER             # check that they are set
```
## Step 2: Run the Containers
### Run the DB container
Manually, run a container from the standard postgres image
but makes use of the environment variables we set; note that
we use the network we just created; and give it a name "db"
```
docker run -d \
    -e POSTGRES_USER=$POSTGRES_USER \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
    --net=example_net --name db \
    postgres
```
### Run the App (interactive)
```
docker run --rm -it \
    -v "$PWD:/usr/src/app" \
    -p 3000:3000 \
    -e POSTGRES_HOST=$POSTGRES_HOST \
    -e POSTGRES_USER=$POSTGRES_USER \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
    --net=example_net --name app \
    example_tag bash
```
We are now inside the rails app container
```
rake db:setup        # create the database over in the 
rake db:migrate      # may not be necessary 
rail s               # run server; go to localhost:3000
ctl-c                # to kill the server
```
lets generate a bit more to the app
```
rails generate scaffold Post name:string title:string body:text
rake db:migrate
```
note we can edit routes from the mac to add a new root to: "posts#index"
```
rails s
```
Create a post via the browser.  We will stop all the containers and restart 
to see if the data persists.
```
ctl-c   # kill the server
exit    # back on the mac 
```
## Step 3: Run App in the Background
Note the database container is still running.  But now run the app as a deamon. 
Note that the dockerfile automatically starts the rails server
```
docker run -d \
    -p 3000:3000 \
    -e POSTGRES_HOST=$POSTGRES_HOST \
    -e POSTGRES_USER=$POSTGRES_USER \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
    --net=example_net --name app \
    -v $PWD:/usr/src/app \
    example_tag
```
Once again you can access the page from the browser at localhost:3000
## Cleanup
shut down all the running containers
```
docker ps -a                    # see all containers
docker stop $(docker ps -a -q)  # stop all containers
docker rm $(docker ps -a -q)    # remove all containers
docker network rm example_net   # remove the network
docker rmi example_tag          # remove the image
docker ps -a                    # empty
docker images                   # gone

docker rmi $(docker images | grep "<none>" | awk '{ print $3 }')
```
## Step: Docker Compose
Docker Compose uses the docker-compose.yml file to 
automate all the complex commands that we did manually
```
docker-compose build                    # creates container with default name
docker images                           # of example_app
docker-compose run app rake db:setup db:migrate   # runs app container with a command

docker ps -a                            # note that the DB also ran and continues

docker-compose stop                     # so lets stop it

docker-compose up                       # start both
docker-compose ps                       # see the list
docker-compose stop                     # from another tab?

docker ps -a                            # see all containers
docker stop $(docker ps -a -q)          # stop all containers
docker rm $(docker ps -a -q)            # remove all containers

docker-compose up -d                    # deamonize
docker-compose stop                     # to stop deamon(s)
docker ps                               # but they are still there
```
## Step 4: Docker Machine
We use Docker Machine to manage virtual machines on which 
we will deploy the containers; this walkthru uses DigitalOcean
to host one machine... puts the two containers on that machine
Note: a DO account and access key was previously created!!!!

first clean up any previous walthru attemps
```
docker-machine ls
docker-machine kill xxxxx               # stops the machine by name
docker-machine rm xxxxx                 # WARNING: removes from cloud
```
create a machine named blogmachine (called a droplet on DO)
```
docker-machine create \
    --driver=digitalocean \
    --digitalocean-access-token=f4fb54e51f72f0477732ea68e2a66139083041a0bbc97739b9570c88be3d8677 \
    --digitalocean-size=1gb blogmachine
```
the machine is now visible on the DO site

as described in the output... connect docker client to the new machine
executint the output of the next command which will set env variables
```
docker-machine env blogmachine
```
start the database container 
```
docker-compose -f docker-compose.prod.yml up -d db
```
build the app container
```
docker-compose -f docker-compose.prod.yml build app
```
ONE TIME run the app container to buid the database
```
docker-compose -f docker-compose.prod.yml run --rm app rake db:create db:migrate
```
run the app container (in the foreground)
```
docker-compose -f docker-compose.prod.yml up app
```
stop both containers
```
docker-compose stop
```
start the app which also starts the db dependecy (as a deamon)
```
docker-compose -f docker-compose.prod.yml up -d
```
now we could walk away and leave it running in the cloud!
