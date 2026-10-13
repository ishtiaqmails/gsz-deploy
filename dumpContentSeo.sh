#!/usr/bin/env bash
# Read-only: shows the article + list render blocks and the post fields, so Claude can write
# a precise SEO patch for guides/articles (meta description, canonical, OG, Article + Breadcrumb schema).
GSZ=/opt/gsz; F="$GSZ/routes/content.js"; cd "$GSZ"
echo "===== content_article render (±14 lines) ====="
awk "/res\.render\('content_article'/{f=NR} f&&NR>=f-14&&NR<=f+16{print NR\": \"\$0}" "$F" | head -34
echo
echo "===== content_list render (±8 lines) ====="
awk "/res\.render\('content_list'/{f=NR} f&&NR>=f-8&&NR<=f+10{print NR\": \"\$0}" "$F" | head -20
echo
echo "===== post SELECT columns (what fields exist) ====="
grep -nE "SELECT .*FROM (posts|content|articles)|excerpt|summary|meta_desc|seo_desc|featured_image|author_name|published_at|updated_at|published|reading_time" "$F" | head -14
