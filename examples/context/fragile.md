# Fragile areas

### src/signup.js
Evidence: 3 of the 4 commits after the initial one touched it, including a revert:
82e81ce (trim before email check) -> a9887b8 (revert: broke valid emails in prod) ->
13ac449 (fix: signup error order again). Error order and email handling are both
proven easy to break. Change with a test that pins the full error array.

## Protected: do not change without a human

- `src/billing.js`: "Do NOT edit `src/billing.js` without the founder's sign-off. It
  changes what customers pay." (CLAUDE.md)
