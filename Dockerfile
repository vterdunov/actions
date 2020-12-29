#syntax=docker/dockerfile:1.2

# ------ build env ------
#
FROM ruby:2.5.1-slim as build-env

ARG RAILS_ROOT=/app
ARG BUILD_PACKAGES="build-essential git curl gnupg2 apt-transport-https ca-certificates apt-utils unzip"
ARG DEV_PACKAGES="postgresql postgresql-contrib libpq-dev libxml2-dev nodejs libmagick++-dev libmagickwand-dev"
ARG RUBY_PACKAGES="tzdata less imagemagick"
ARG BUNDLER_VERSION="2.0.1"
ARG SECRET_KEY="secret_key"
ARG LICENSE_KEY

ENV RAILS_ENV=production
ENV NODE_ENV=production
ENV SECRET_KEY_BASE="$SECRET_KEY"

WORKDIR $RAILS_ROOT

RUN rm -f /etc/apt/apt.conf.d/docker-clean && \
  echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

# install packages
RUN --mount=type=cache,sharing=locked,target=/var/cache/apt --mount=type=cache,sharing=locked,target=/var/lib/apt \
  apt update -qq && \
  apt-get install -y --no-install-recommends $BUILD_PACKAGES $DEV_PACKAGES $RUBY_PACKAGES && \
  gem install bundler:$BUNDLER_VERSION

# Install NodeJS
RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt \
  curl -sL https://deb.nodesource.com/setup_14.x | bash - && \
  apt update -qq && apt install -y nodejs

# Install Yarn
RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt \
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
  apt update -qq && apt install -y yarn


# ------ Application code ------
#
# is used to run unit tests on CI. No need to wait for assets. See: docker-compose.ci.yml
FROM build-env as code

COPY . .

# ------ Final image ------
#
FROM ruby:2.5.1-slim as final

ARG RAILS_ROOT=/app
ARG PACKAGES="git curl gnupg2 ca-certificates"
ARG RUBY_PACKAGES="tzdata less imagemagick postgresql postgresql-contrib"
ARG BUNDLER_VERSION="2.0.1"

ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=1
ENV RAILS_SERVE_STATIC_FILES=1
ENV GEOLITE_CITY_PATH="${RAILS_ROOT}/db/GeoLite2-City.mmdb"

# install packages
RUN --mount=type=cache,sharing=locked,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt \
  apt-get update -qq && \
  apt-get install --no-install-recommends -y $PACKAGES $RUBY_PACKAGES && \
  gem install bundler:${BUNDLER_VERSION}

ARG APP_UID=864
ARG APP_GID=864

RUN addgroup --system --gid $APP_GID app && \
  adduser --system --uid $APP_UID --ingroup app app

WORKDIR $RAILS_ROOT
RUN chown app:app $RAILS_ROOT

USER app

COPY --from=build-env --chown=app /usr/local/bundle /usr/local/bundle

EXPOSE 3000
