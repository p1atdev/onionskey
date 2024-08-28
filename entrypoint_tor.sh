#!/bin/sh

chown -R root /etc/tor
chmod 400 -R /etc/tor/hidden_service

exec "$@"
