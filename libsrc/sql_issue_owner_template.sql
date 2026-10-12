-- Owner alert template (sent to wa_owner_numbers via the Verification Bot outbox).
INSERT INTO wa_templates(key, body, langs, updated_at)
VALUES(
  'whatsapp.issue_owner_alert',
  E'🆕 *{{kind}}* — {{order_no}}\nFrom: {{customer}}\n\n{{message}}\n\nOpen: {{admin_url}}',
  NULL,
  now()
)
ON CONFLICT(key) DO NOTHING;
