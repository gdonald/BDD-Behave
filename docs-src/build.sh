#!/bin/sh

cd "$(dirname "$0")"
mkdocs gh-deploy --force
