#!/usr/bin/env bash
# dumpH4 — auth pages + shared auth styles (to fix the flat-grey submit button).
GSZ=/opt/gsz; cd "$GSZ"
for f in views/partials/auth_style.ejs views/account/login.ejs views/account/signup.ejs views/account/forgot.ejs views/account/reset.ejs; do
  echo "########## $f ($(wc -l < "$f") lines) ##########"
  cat -n "$f"
  echo
done
