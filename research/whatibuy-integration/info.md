# WhatIBuy - Grocery Integration Research

## Background
WhatIBuy (operated by the Danish company Kauza ApS / What I Buy ApS) is a digital service and mobile app available in Denmark (`whatibuy.dk`), Norway (`whatibuy.no`), and Sweden. The app aggregates digital grocery receipts to provide users with automated budgeting, spending insights (e.g., categories like meat, vegetables, sweets), and sustainability metrics (organic percentage).

## Integration Strategy in Norway
In the Norwegian market, WhatIBuy successfully aggregates data from the three major grocery loyalty programs:
1. **Trumf** (NorgesGruppen: Kiwi, Meny, Spar, Joker)
2. **Coop** (Coop Mega, Extra, Obs, Prix)
3. **Æ** (Rema 1000)

### How They Connect
There are no official, open public APIs provided by these Norwegian grocery giants for third-party aggregators. Therefore, WhatIBuy utilizes the following strategy:

1. **User Consent & Credential/Token Access:**
   - The app asks for the user's explicit consent to retrieve data from their respective loyalty accounts.
   - Users authenticate with their Trumf, Coop, and Æ credentials within the WhatIBuy app.
   - Because there are no official B2B APIs for this, WhatIBuy acts as a client impersonating the user's mobile app sessions (similar to the reverse-engineered OAuth/PKCE flows documented by researchers like Helge Sverre). 

2. **Automated Scraping/Fetching:**
   - Once connected, WhatIBuy periodically fetches the digital receipt data from the internal APIs of Trumf, Coop, and Æ.
   - This data contains the detailed line items (EANs, product names, prices) which WhatIBuy then categorizes.

3. **Storebox Integration (Denmark/General):**
   - In Denmark, and potentially as a fallback for certain systems, WhatIBuy explicitly mentions integration with **Storebox**. Storebox is a digital receipt provider widely used by merchants in the Nordics. Integrating with Storebox via user credentials allows them to bypass the grocers' proprietary apps in cases where Storebox is the underlying receipt engine.

### Business & Legal Posture
- **Independent Third Party:** WhatIBuy has no official partnerships with NorgesGruppen, Coop Norge, or Rema 1000. 
- **Consumer Rights (GDPR):** They position their service around the consumer's right to their own data. By acting on behalf of the user (with explicit consent), they navigate the gray area of scraping internal APIs.
- **Instability:** User reviews on app stores frequently complain about integrations (especially Trumf) breaking or failing to sync. This is a hallmark symptom of relying on undocumented, reverse-engineered APIs; whenever the grocery chains update their apps or authentication flows, the WhatIBuy scrapers break and require maintenance.

## Summary
WhatIBuy managed to integrate with the stores not through official B2B partnerships, but by building a "Bring Your Own Credentials" (BYOC) scraping engine. They authenticate against the undocumented internal APIs of Trumf, Coop, and Æ on behalf of the user. This approach allows them to offer a unified dashboard but suffers from fragility whenever the underlying grocery apps update their security or API structures.