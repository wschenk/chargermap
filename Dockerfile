FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ruby ruby-dev \
    build-essential curl \
    sqlite-utils \
    python3-click-default-group \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN gem install bundler:2.3.26

COPY Gemfile* ./
RUN bundle install

COPY *.rb *.txt config.ru run ./

EXPOSE 8080
CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "--port", "8080"]
