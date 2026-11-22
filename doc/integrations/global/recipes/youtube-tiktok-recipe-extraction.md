---
id: global-youtube-tiktok-recipe-extraction
name: YouTube / TikTok recipe extraction
scope: global
category: recipes
operator: Google (YouTube) / ByteDance (TikTok)
access: [api-public, bot]
auth: oauth2
data: [recipes]
item_level: false
cost: freemium
user_base: Billions of users; huge recipe content
tos_risk: high
fit: 3
status: researched
last_verified: 2026-11-21
---

# YouTube / TikTok recipe extraction

Recipes shared as videos. FoodSavr could accept a shared video URL, fetch the transcript/description and use an LLM to extract an ingredient list and steps.

## Access

- **api-public** - YouTube Data API v3 (`videos.list` for description, `captions` requires owner auth; quota-based) at `https://developers.google.com/youtube/v3`.
- **bot** - TikTok has no public API for arbitrary video text beyond oEmbed (title/author); transcripts need scraping or user-provided text (unverified).
- LLM extraction from description/transcript is the main value (no official recipe API).

## Data

Video title, description (often contains ingredients), optional transcript.

## FoodSavr mapping

Share-sheet import to recipes via LLM structuring; user supplies the link.

## Risks and constraints

- Scraping TikTok/YouTube transcripts breaches ToS; use description/oEmbed and user-supplied text.

## Existing work

- Open-source transcript tools exist (youtube-transcript-api; unverified ToS status).

## Sources

- https://developers.google.com/youtube/v3 - YouTube API
- https://developers.tiktok.com/doc/embed-videos - TikTok oEmbed
