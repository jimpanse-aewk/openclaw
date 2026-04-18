#!/usr/bin/env bash

export PATH="/home/clown/.npm-global/bin:$PATH"

set -a
source /home/clown/.config/openclaw/secrets.env
set +a

cd /home/clown
exec /home/clown/.npm-global/bin/openclaw
