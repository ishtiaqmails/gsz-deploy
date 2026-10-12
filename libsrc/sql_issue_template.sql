-- WhatsApp template for issue-thread updates, sent via the Verification Bot outbox.
-- ON CONFLICT DO NOTHING so a later admin edit of the template is never overwritten.
INSERT INTO wa_templates(key, body, langs, updated_at)
VALUES(
  'whatsapp.issue_update',
  E'💬 *Update on your request*  ({{order_no}})\n\n{{message}}\n\n👉 You can reply anytime from your account: {{account_url}}',
  NULL,
  now()
)
ON CONFLICT(key) DO NOTHING;
