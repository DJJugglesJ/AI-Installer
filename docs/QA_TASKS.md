# QA Follow-up Tasks

## CharacterCard serialization round-trip mismatch
- [ ] Add/extend regression coverage for `trigger_token`/`trigger_tokens` parity in `tests/test_character_cards.py`.
- [ ] Validate serialization expectations in `modules/runtime/character_studio/models.py` (ensure the derived `trigger_tokens` list always reflects `trigger_token`).
- [ ] Document expected behavior in the Character Studio docs once the fix is confirmed.

Note: Tasks captured from the former `qa_logs/forensic_diagnostics.md` report (removed after capture).
