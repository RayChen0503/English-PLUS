# Archived Firebase Functions Prototype

This directory preserves the original OpenRouter/Firebase Functions proxy for migration history only. It is not part of the current English+ runtime and must not be deployed.

The production AI route is the authenticated Cloudflare Worker in `workers/englishplus-ai-proxy`, backed by Groq. `firebase.json` deliberately contains no Functions deployment block so a normal Firebase deploy cannot publish this obsolete proxy.
