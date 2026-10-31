#!/usr/bin/env bash
# dumpHubAuth.sh — find EVERY place the site signs in / creates an account, so I can make them
# all consistent with the fixed /login + /signup. Targeted output (usage-friendly).
set -uo pipefail
GSZ=/opt/gsz

echo "========== A) files that contain an auth UI (login/signup forms, hub modal) =========="
grep -rln "Email or WhatsApp\|Sign in to your Galaxy Hub\|Welcome back\|Create an account\|name=\"password\"" "$GSZ/views" 2>/dev/null

echo
echo "========== B) the Galaxy Hub modal file =========="
HUB=$(grep -rln "Sign in to your Galaxy Hub\|Email or WhatsApp" "$GSZ/views" 2>/dev/null | head -1)
echo "HUB FILE: $HUB"
echo "lines: $(wc -l < "$HUB" 2>/dev/null)"
echo
echo "--- marker lines (so I can see the auth block layout) ---"
grep -n "Welcome back\|Email or WhatsApp\|Create an account\|New here\|Sign in to your Galaxy Hub\|type=\"password\"\|name=\"email\"\|name=\"wa\|name=\"name\"\|name=\"password\"\|Create account\|Sign In\|id=\"\|class=\"hub\|data-tab\|data-view\|data-act" "$HUB" 2>/dev/null | head -70

echo
echo "========== C) how the hub auth submits (endpoints, field names, country handling) =========="
grep -n "fetch(\|/login\|/signup\|wa_country\|XMLHttpRequest\|\.submit(\|action=\|method=\|normalize\|ajax" "$HUB" 2>/dev/null | head -50

echo
echo "========== D) other auth entry points — checkout login gate + trial gate =========="
echo "--- checkout (login/create-account inside checkout?) ---"
grep -rn "Email or WhatsApp\|Create an account\|Sign in\|/login\|/signup\|name=\"password\"" "$GSZ/views/checkout"*.ejs "$GSZ/views/"*checkout*.ejs 2>/dev/null | head -20
echo "--- anywhere else linking/redirecting to sign in or create account ---"
grep -rn "href=\"/login\"\|href=\"/signup\"\|location.*'/login'\|location.*'/signup'\|openHub\|showLogin\|data-login\|data-signup" "$GSZ/views" 2>/dev/null | head -25

echo
echo "DONE"
