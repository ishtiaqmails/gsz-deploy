-- 001_geo_seo_core.sql — additive foundation for the Geo Page Engine + Search Intelligence core.
-- 100% additive: new tables + indexes only, all IF NOT EXISTS, seeds ON CONFLICT DO NOTHING.
-- Runs inside a single transaction (see migrate.js) — all-or-nothing, safe to re-run.

-- ============================ GEO PAGE ENGINE ============================

CREATE TABLE IF NOT EXISTS geo_locations (
  id              SERIAL PRIMARY KEY,
  type            TEXT NOT NULL DEFAULT 'city',        -- global|country|region|city|area
  name            TEXT NOT NULL,
  slug            TEXT NOT NULL,
  country_code    TEXT,
  iso_code        TEXT,
  parent_id       INTEGER REFERENCES geo_locations(id) ON DELETE SET NULL,
  currency        TEXT,
  currency_symbol TEXT,
  timezone        TEXT,
  languages       JSONB DEFAULT '[]'::jsonb,
  latitude        NUMERIC(9,6),
  longitude       NUMERIC(9,6),
  population      BIGINT,
  demonym         TEXT,
  enabled         BOOLEAN NOT NULL DEFAULT TRUE,
  seo_enabled     BOOLEAN NOT NULL DEFAULT TRUE,
  indexable       BOOLEAN NOT NULL DEFAULT TRUE,
  priority        INTEGER NOT NULL DEFAULT 100,
  metadata        JSONB DEFAULT '{}'::jsonb,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_geo_loc_type_slug ON geo_locations(type, slug);
CREATE INDEX IF NOT EXISTS ix_geo_loc_parent  ON geo_locations(parent_id);
CREATE INDEX IF NOT EXISTS ix_geo_loc_country ON geo_locations(country_code);
CREATE INDEX IF NOT EXISTS ix_geo_loc_slug    ON geo_locations(slug);

CREATE TABLE IF NOT EXISTS geo_product_rules (
  id               SERIAL PRIMARY KEY,
  product_id       INTEGER,                            -- soft ref to products.id
  category_id      INTEGER,                            -- soft ref to categories.id
  location_id      INTEGER REFERENCES geo_locations(id) ON DELETE CASCADE,
  availability     TEXT DEFAULT 'available',           -- available|limited|unavailable
  enabled          BOOLEAN NOT NULL DEFAULT TRUE,
  priority         INTEGER NOT NULL DEFAULT 100,
  recommendation_score NUMERIC(6,2) DEFAULT 0,
  recommended      BOOLEAN NOT NULL DEFAULT FALSE,
  featured         BOOLEAN NOT NULL DEFAULT FALSE,
  trial_available  BOOLEAN,
  trial_duration   TEXT,
  regional_price   NUMERIC(12,2),
  currency_override TEXT,
  regional_description TEXT,
  vpn_required     BOOLEAN DEFAULT FALSE,
  special_notice   TEXT,
  purchase_url_override TEXT,
  cta_override     TEXT,
  seo_enabled      BOOLEAN NOT NULL DEFAULT TRUE,
  metadata         JSONB DEFAULT '{}'::jsonb,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_gpr_product_loc  ON geo_product_rules(product_id, location_id);
CREATE INDEX IF NOT EXISTS ix_gpr_category_loc ON geo_product_rules(category_id, location_id);
CREATE INDEX IF NOT EXISTS ix_gpr_location     ON geo_product_rules(location_id);

CREATE TABLE IF NOT EXISTS geo_intents (
  id             SERIAL PRIMARY KEY,
  key            TEXT UNIQUE NOT NULL,
  name           TEXT NOT NULL,
  slug           TEXT,                                 -- url segment; NULL = base landing
  title_template TEXT,
  meta_template  TEXT,
  block_config   JSONB DEFAULT '{}'::jsonb,
  enabled        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO geo_intents(key,name,slug) VALUES
  ('BEST','Best products',NULL),
  ('BUY','Buy',NULL),
  ('PRICE','Pricing','pricing'),
  ('TRIAL','Free trial','free-trial'),
  ('COMPARE','Compare','compare'),
  ('REVIEW','Reviews','reviews'),
  ('LOCAL','Local',NULL),
  ('DEVICE','Device',NULL),
  ('CHANNELS','Channels','channels'),
  ('SPORTS','Sports','sports'),
  ('HOW_TO','How to','how-to'),
  ('AVAILABILITY','Availability',NULL),
  ('PROBLEM_SOLUTION','Problem / solution',NULL)
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS geo_pages (
  id              SERIAL PRIMARY KEY,
  page_type       TEXT NOT NULL DEFAULT 'COUNTRY_LANDING',
  product_id      INTEGER,
  category_id     INTEGER,
  country_id      INTEGER REFERENCES geo_locations(id) ON DELETE CASCADE,
  region_id       INTEGER REFERENCES geo_locations(id) ON DELETE SET NULL,
  city_id         INTEGER REFERENCES geo_locations(id) ON DELETE SET NULL,
  intent_id       INTEGER REFERENCES geo_intents(id)   ON DELETE SET NULL,
  language        TEXT NOT NULL DEFAULT 'en',
  title           TEXT,
  slug            TEXT NOT NULL,                        -- full path, e.g. /iptv/pakistan/peshawar
  status          TEXT NOT NULL DEFAULT 'DRAFT',        -- DRAFT|REVIEW|PUBLISHED|ARCHIVED
  indexing_status TEXT NOT NULL DEFAULT 'AUTO',         -- INDEX|NOINDEX|AUTO
  manual_override BOOLEAN NOT NULL DEFAULT FALSE,
  template_key    TEXT,
  seo_title       TEXT,
  seo_description TEXT,
  canonical_url   TEXT,
  content_data    JSONB DEFAULT '{}'::jsonb,
  block_config    JSONB,
  quality_score   INTEGER,
  duplicate_score INTEGER,
  opportunity_score INTEGER,
  published_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_geo_pages_slug   ON geo_pages(slug);
CREATE INDEX IF NOT EXISTS ix_geo_pages_status  ON geo_pages(status, indexing_status);
CREATE INDEX IF NOT EXISTS ix_geo_pages_country ON geo_pages(country_id);
CREATE INDEX IF NOT EXISTS ix_geo_pages_city    ON geo_pages(city_id);

-- ======================= SEARCH INTELLIGENCE CORE =======================

CREATE TABLE IF NOT EXISTS seo_urls (
  id               SERIAL PRIMARY KEY,
  url              TEXT NOT NULL,
  normalized_url   TEXT NOT NULL,
  entity_type      TEXT,                                -- product|category|page|geo_page|blog|static
  entity_id        INTEGER,
  canonical_url    TEXT,
  http_status      INTEGER,
  indexable        BOOLEAN,
  crawl_priority   NUMERIC(6,2) DEFAULT 100,
  crawl_depth      INTEGER,
  content_hash     TEXT,
  schema_hash      TEXT,
  lifecycle_state  TEXT DEFAULT 'DISCOVERED',
  health_score     INTEGER,
  technical_score  INTEGER,
  content_score    INTEGER,
  schema_score     INTEGER,
  link_score       INTEGER,
  performance_score INTEGER,
  last_changed_at   TIMESTAMPTZ,
  last_crawled_at   TIMESTAMPTZ,
  last_validated_at TIMESTAMPTZ,
  last_submitted_at TIMESTAMPTZ,
  metadata         JSONB DEFAULT '{}'::jsonb,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_seo_urls_norm  ON seo_urls(normalized_url);
CREATE INDEX IF NOT EXISTS ix_seo_urls_entity   ON seo_urls(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS ix_seo_urls_state    ON seo_urls(lifecycle_state);
CREATE INDEX IF NOT EXISTS ix_seo_urls_priority ON seo_urls(crawl_priority DESC);

CREATE TABLE IF NOT EXISTS seo_issues (
  id            SERIAL PRIMARY KEY,
  url_id        INTEGER REFERENCES seo_urls(id) ON DELETE CASCADE,
  url           TEXT,
  code          TEXT NOT NULL,                          -- MISSING_CANONICAL, BROKEN_INTERNAL_LINK, ...
  severity      TEXT NOT NULL DEFAULT 'WARNING',        -- INFO|WARNING|HIGH|CRITICAL
  status        TEXT NOT NULL DEFAULT 'OPEN',           -- OPEN|AUTO_FIXING|FIXED|FAILED|IGNORED|MANUAL_REVIEW|RECURRING
  auto_fixable  BOOLEAN DEFAULT FALSE,
  evidence      JSONB DEFAULT '{}'::jsonb,
  detected_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_checked_at TIMESTAMPTZ,
  resolved_at   TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS ix_seo_issues_status ON seo_issues(status, severity);
CREATE INDEX IF NOT EXISTS ix_seo_issues_url    ON seo_issues(url_id);
CREATE INDEX IF NOT EXISTS ix_seo_issues_code   ON seo_issues(code);

CREATE TABLE IF NOT EXISTS seo_submissions (
  id           SERIAL PRIMARY KEY,
  url          TEXT NOT NULL,
  engine       TEXT NOT NULL DEFAULT 'indexnow',        -- indexnow|bing|google|sitemap
  action       TEXT DEFAULT 'submit',
  status       TEXT,
  response     JSONB DEFAULT '{}'::jsonb,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_seo_sub_url  ON seo_submissions(url);
CREATE INDEX IF NOT EXISTS ix_seo_sub_time ON seo_submissions(submitted_at DESC);

CREATE TABLE IF NOT EXISTS seo_links (
  id          SERIAL PRIMARY KEY,
  source_url  TEXT NOT NULL,
  dest_url    TEXT NOT NULL,
  anchor      TEXT,
  rel         TEXT,
  crawl_run   INTEGER,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_seo_links_src  ON seo_links(source_url);
CREATE INDEX IF NOT EXISTS ix_seo_links_dest ON seo_links(dest_url);

-- Dormant until Search Console / Bing credentials are added:
CREATE TABLE IF NOT EXISTS seo_search_metrics (
  id          SERIAL PRIMARY KEY,
  url         TEXT,
  query       TEXT,
  engine      TEXT DEFAULT 'google',
  country     TEXT,
  device      TEXT,
  date        DATE,
  clicks      INTEGER DEFAULT 0,
  impressions INTEGER DEFAULT 0,
  ctr         NUMERIC(6,4),
  position    NUMERIC(6,2),
  synced_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_seo_sm_unique ON seo_search_metrics(url, query, engine, country, device, date);
CREATE INDEX IF NOT EXISTS ix_seo_sm_url  ON seo_search_metrics(url);
CREATE INDEX IF NOT EXISTS ix_seo_sm_date ON seo_search_metrics(date);
