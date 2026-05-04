#!/bin/sh

rm -rf ../docs
mkdocs build
mv site ../docs
