FROM ruby:2.3 

RUN apt-get update -yqq \
  && apt-get install -yqq --no-install-recommends postgresql-client \
  && rm -rf /var/lib/apt/lists

WORKDIR /usr/src/app
COPY Gemfile* ./
RUN bundle install
COPY . ./

EXPOSE 3000
# previous executions seem to leave this pid file laying around
# which prevents the next rails invocation to fail to execute
# so we remove it before starting up rails
CMD rm -rf ./tmp/pids/server.pid && rails s -b 0.0.0.0 -p 3000