# env.template Notes

This repository includes `env.template` for local development.

## How to use
1. Copy the template:
   - `cp env.template .env`
2. Fill only local values in `.env` (RPC URLs, local keys, etc.)
3. Never commit `.env`

## Common pitfalls
- Do not paste production keys
- Use separate test wallets for dev
- Prefer a local node or dedicated test RPC

## Quick sanity check
- `.env` is in `.gitignore`
- No secrets appear in `git diff`
