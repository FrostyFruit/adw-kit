# Handover: 20261001-061108-annual-growth-plan

**Ticket (feature):** add an annual version of the growth plan, billed yearly.
**Base:** 27fba8e. **Result:** approved by a fresh reviewer, verify green on attempt 1.

## Human decisions
1. Edit protected `src/billing.js`: "Yes, you may edit src/billing.js for this ticket. The plan key is growth_annual and the price is 990 a year."
2. Plan key: same reply. The key is `growth_annual`.
3. Annual price: same reply. The price is 990 a year.
4. Who makes external callers charge it yearly: "Go with your suggested answer." That means 990 is charged once a year, the external billing caller owns scheduling it yearly, and this ticket adds only the price (no interval field).

## What changed
- `src/billing.js`: one line. `PRICES` gains `growth_annual: 990`. Nothing else in the file changed.
- `test/billing.test.js`: pins starter 49, growth 99 and scale 199. Adds `growth_annual costs 990 per year`. Unknown plans throw with the exact message (`growth_yearly`), and the near-miss `Growth_Annual` is not normalised.

## Verify (attempt 1)
- test: pass (`# pass 7`)
- copy-length: pass (`check-copy: 2 strings OK`)
- run-file: pass

## Review
Fresh subagent, full round. **approve**, diff_lines 16, 5 of 5 criteria met.

Unscoped findings:
- No behaviour beyond the criteria. Two files changed, nothing committed during the run.
- Residual risk: nothing in the code says `growth_annual` is yearly. `priceFor` returns a bare 990, and "per year" exists only in a test title. A caller that charges monthly would charge 990 a month.
- Pre-existing: `plan in PRICES` matches prototype keys, so `priceFor('toString')` returns a function. Unchanged by this run.

## Accepted risks (plan.risky_assumptions)
- "Billed yearly" is expressed only by the separate key and its yearly amount. No billing interval is recorded anywhere in this repo.
- ACCEPTED (decision 4): external callers will schedule `growth_annual` yearly. If one charges it monthly, the customer is overcharged 12 times. This repo cannot check that.

## Open questions
- CLAUDE.md requires the founder's sign-off for `src/billing.js`. The approval is recorded word for word, but the reply does not say who gave it. Confirm the approver was the founder (challenge round 1, minor).

## Follow-up tickets (filed here, per challenge round 2)
1. **Caller-side yearly billing (owner: external billing caller).** `priceFor('growth_annual')` returns 990, a once-a-year amount. Every caller that charges, displays ("/mo"), computes MRR, or diffs plan prices for upgrades must treat `growth_annual` as yearly. Done when those callers charge 990 once a year.
2. **`priceFor` prototype-chain lookup (needs founder sign-off: protected file).** Replace `plan in PRICES` with an own-property check (for example `Object.hasOwn(PRICES, plan)`), so that `priceFor('toString')` and `priceFor('constructor')` throw `unknown plan`.

## For the next person
- `PRICES` is a flat key-to-amount map with no interval. A new billing period means a new key plus caller-side work, or a deliberate change to the data shape (founder sign-off required).
- Keep negative billing tests to non-prototype names until follow-up 2 lands.
