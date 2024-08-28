#!/bin/bash

set -xe

git config --global --add safe.directory /workspace
git submodule update --init
corepack install
corepack enable
bun install --frozen-lockfile
cp .devcontainer/devcontainer.yml .config/default.yml
bun run build
bun run migrate
