GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "===== TABLES in admin views (rsp vs plain) ====="
for f in views/admin/*.ejs; do
  case "$f" in *bak*) continue;; esac
  n=$(grep -c "<table" "$f"); [ "$n" -gt 0 ] || continue
  r=$(grep -c "table class=\"rsp\"\|table class='rsp'\|<table class=.rsp" "$f")
  echo "$(basename "$f"): tables=$n rsp=$r"
done
echo
echo "===== plain <table> lines (not rsp) with context ====="
grep -rn "<table" views/admin/*.ejs | grep -v bak | grep -v "class=\"rsp\"" | head -40
echo
echo "===== inline multi-col grids in admin views (may need stacking) ====="
grep -rno "grid-template-columns:[^\"';]*" views/admin/*.ejs | grep -v bak | grep -vE "1fr *!important|repeat\(auto" | sort | uniq -c | sort -rn | head -30
echo DONE
