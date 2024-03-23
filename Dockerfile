FROM debian:bookworm-slim

RUN apt-get update
RUN apt-get install -y ruby ruby-dev \
    build-essential curl sqlite-utils \
    python3-click-default-group

# Install node
RUN apt-get install -y nodejs npm

# Install chrome and dependencies
RUN apt-get install -y wget gpg
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/googlechrome-linux-keyring.gpg \
    && sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/googlechrome-linux-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
    && apt-get update
RUN apt-get install -y google-chrome-stable fonts-freefont-ttf libxss1 \
    --no-install-recommends

WORKDIR /app

RUN gem install bundler:2.3.26

COPY package* ./
RUN npm i

COPY Gemfile* ./
RUN bundle install

COPY * ./

EXPOSE 8080
CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "--port", "8080"]
