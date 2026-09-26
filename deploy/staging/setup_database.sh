#!/bin/bash
# Fork only: first time database setup for the OFN staging instance. Run as root, once.
# Loads the schema, seeds with German states instead of the default Australian ones (what
# ofn-install does per instance), then adds the demo data.
set -euo pipefail
APP=/opt/ofn/app

as_ofn() {
  su - ofn -c "set -a; source /opt/ofn/ofn.env; set +a
    export RAILS_ENV=production PATH=\$HOME/.rbenv/shims:\$HOME/.rbenv/bin:\$HOME/node/bin:\$PATH
    cd $APP && $*"
}

as_ofn "cp deploy/staging/states_de.yml db/default/spree/states.yml"
as_ofn "bin/rails db:create db:schema:load db:seed" || { as_ofn "git checkout -- db/default/spree/states.yml"; exit 1; }
as_ofn "git checkout -- db/default/spree/states.yml"
as_ofn "bin/rails runner deploy/staging/europe_zone.rb"
as_ofn "bin/rails runner deploy/staging/content_config.rb"
as_ofn "bin/rails runner deploy/staging/demo_data.rb"
as_ofn "bin/rails runner deploy/staging/enhance_demo.rb"
as_ofn "bin/rails runner deploy/staging/use_demo_photos.rb"
