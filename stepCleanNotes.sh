#!/usr/bin/env bash
# Remove duplicated 'old warranty' text from product notes (warranty comes only from the admin
# Product Model warranty field). Surgical + reversible from admin.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc
echo "--- cleaning warranty duplication out of product notes ---"
node "$SRC/clean_notes.js"
echo "DONE — reload any product page: warranty now appears once, from your Product Model."
