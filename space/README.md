---
title: Jean API
emoji: ⚡
colorFrom: gray
colorTo: red
sdk: docker
app_port: 7860
pinned: false
license: mit
short_description: Your own OpenAI-compatible API, free on CPU
---

# Jean API

Your own OpenAI-compatible endpoint with **Jean Grey** and **Jean Marvel**, running on the free
"CPU basic" hardware of Hugging Face Spaces. Built from
[Jean-API-Generator](https://github.com/jeancodeeer/Jean-API-Generator).

- **URL for your client:** `https://<your-user>-<space-name>.hf.space/v1`
- **Key:** the `JEAN_API_KEY` secret of this Space (Settings → Variables and secrets).
  Every request needs `Authorization: Bearer <key>`; only `/health` answers without it.
- **Models:** `jean-grey` and `jean-marvel`, 32k context each. Both load in 2–4 minutes after
  the Space starts.

Personal use. CPU only, so expect a few tokens per second. A free Space sleeps after 48 hours
without visits and wakes up on the next request.
