-- Coupon product-scoping link table (#80).
-- No rows for a coupon  = applies to ALL products (overall).
-- One or more rows      = coupon is valid only when every ordered product is in this set.
CREATE TABLE IF NOT EXISTS coupon_products (
  coupon_id  integer NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
  product_id integer NOT NULL,
  PRIMARY KEY (coupon_id, product_id)
);
CREATE INDEX IF NOT EXISTS idx_coupon_products_cid ON coupon_products(coupon_id);
