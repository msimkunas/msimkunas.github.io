FROM ruby:3.2

WORKDIR /srv/jekyll

RUN gem install bundler

EXPOSE 4000

RUN --mount=type=bind,source=.,target=/srv/jekyll bundle install

CMD bundle exec jekyll serve --host 0.0.0.0
