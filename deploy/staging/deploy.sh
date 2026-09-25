#!/bin/bash
# Fork only: deploys this branch to the OFN staging instance (ofn.hof-homann.de) on the shared
# staging server. Run as root:  /opt/ofn/app/deploy/staging/deploy.sh [branch]
#
# Layout: user "ofn", home /opt/ofn, app in /opt/ofn/app, settings and secrets in /opt/ofn/ofn.env
# (never in the repo), Ruby via rbenv, Node in /opt/ofn/node, Postgres 16 and the shared Redis
# (databases 1-3) on localhost, Puma on 127.0.0.1:8150 behind nginx.
set -euo pipefail

BRANCH="${1:-feature/home-products}"
APP=/opt/ofn/app

as_ofn() {
  su - ofn -c "set -a; source /opt/ofn/ofn.env; set +a
    export RAILS_ENV=production NODE_ENV=production
    export PATH=\$HOME/.rbenv/shims:\$HOME/.rbenv/bin:\$HOME/node/bin:\$PATH
    cd $APP && $*"
}

as_ofn "git fetch -q origin $BRANCH && git checkout -q -B $BRANCH origin/$BRANCH && git log --oneline -1"
as_ofn "bundle config set --local deployment true && bundle config set --local without 'development test' && bundle install --jobs 3 --quiet"
as_ofn "yarn install --frozen-lockfile --silent"
as_ofn "nice -n 10 bin/rails assets:precompile"
as_ofn "bin/rails db:migrate"

systemctl restart ofn-web ofn-worker
sleep 5
systemctl is-active ofn-web ofn-worker
curl -s -o /dev/null -w "home: %{http_code}\n" -H "Host: ofn.hof-homann.de" \
  -H "X-Forwarded-Proto: https" http://127.0.0.1:8150/
