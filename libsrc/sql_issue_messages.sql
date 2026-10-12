-- Issue chat threads: one row per message (customer or admin), optional screenshot.
-- Idempotent: safe to run repeatedly. Seeds existing order_issues into the thread once.
CREATE TABLE IF NOT EXISTS issue_messages(
  id         serial PRIMARY KEY,
  issue_id   integer NOT NULL REFERENCES order_issues(id) ON DELETE CASCADE,
  sender     text NOT NULL CHECK (sender IN ('customer','admin')),
  body       text,
  screenshot text,
  seen_by_admin    boolean NOT NULL DEFAULT false,
  seen_by_customer boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS issue_messages_issue_idx ON issue_messages(issue_id, id);
ALTER TABLE issue_messages OWNER TO gsz_user;
ALTER SEQUENCE issue_messages_id_seq OWNER TO gsz_user;

-- Seed the original customer report as the first message (only if the issue has no thread yet).
INSERT INTO issue_messages(issue_id, sender, body, screenshot, seen_by_admin, seen_by_customer, created_at)
SELECT i.id, 'customer', i.message, i.screenshot, true, true, i.created_at
FROM order_issues i
WHERE (i.message IS NOT NULL OR i.screenshot IS NOT NULL)
  AND NOT EXISTS (SELECT 1 FROM issue_messages m WHERE m.issue_id = i.id);

-- Seed the single historical admin response as the next message (only if no admin message exists).
INSERT INTO issue_messages(issue_id, sender, body, screenshot, seen_by_admin, seen_by_customer, created_at)
SELECT i.id, 'admin', i.admin_response, i.admin_screenshot, true, true, COALESCE(i.resolved_at, i.created_at)
FROM order_issues i
WHERE (i.admin_response IS NOT NULL OR i.admin_screenshot IS NOT NULL)
  AND NOT EXISTS (SELECT 1 FROM issue_messages m WHERE m.issue_id = i.id AND m.sender = 'admin');
