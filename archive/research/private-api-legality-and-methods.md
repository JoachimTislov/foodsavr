# Private APIs: The Mechanics of Reverse Engineering and Legal Implications

When building aggregators like Kassal.app or WhatIBuy, developers frequently rely on "private" APIs—endpoints built strictly for an official mobile app (like the Rema 1000 Æ app or Coop Medlem app) that are not publicly documented. 

This document explores exactly **how** developers manage to figure out these private endpoints, and **the legality** of calling them.

---

## Part 1: How Are Private APIs Discovered? (The Technical Process)

Companies do not publish the documentation for their internal APIs. Instead, developers discover them through **Reverse Engineering**. The core principle is that the mobile app lives on a device controlled by the user. Because "the client cannot be trusted," any secret the app knows, a determined developer can extract.

Here is the typical process a developer follows to map out a private API:

### 1. Traffic Interception (Man-in-the-Middle)
The easiest way to understand an API is to watch the app talk to the server.
*   **The Method:** The developer connects their smartphone to a proxy server running on their computer (e.g., using tools like `mitmproxy`, `Charles Proxy`, or `Proxyman`). 
*   **The Result:** By clicking around the grocery app (e.g., opening a receipt, fetching coupons), the developer can see the exact HTTP requests. They capture the endpoint URLs (e.g., `https://api.rema.no/...`), the JSON payload structures, and the required authentication headers.

### 2. Defeating SSL Certificate Pinning
To prevent traffic interception, most modern apps use "SSL Pinning"—they hardcode the server's security certificate inside the app and refuse to talk through a proxy.
*   **The Bypass:** The developer uses a "rooted" Android phone or "jailbroken" iPhone. They install dynamic instrumentation frameworks like **Frida** or **Xposed**. These tools inject code into the running app to intercept the network libraries (like OkHttp) and disable the SSL pinning checks in memory. Once disabled, the proxy tool from Step 1 can see the traffic again in plain text.

### 3. App Decompilation (Static Analysis)
Sometimes, observing traffic isn't enough. An API might require a special API key or a secret hash that isn't easily understood just by looking at the network.
*   **The Method:** The developer downloads the Android application package (`.apk` file) and uses decompilers like `jadx` or `apktool` to turn the compiled app back into readable Java/Kotlin source code (or Dart, in the case of Flutter apps like Coop).
*   **The Result:** By searching through the source code, they find hardcoded secrets. For example, in the Rema 1000 app, developers found the hardcoded Azure API Management key (`Ocp-Apim-Subscription-Key`) and the OAuth Client ID simply by reading the decompiled text.

### 4. Client Impersonation (Building the Integration)
Once the developer has mapped the URLs, the required headers, the hidden keys, and the login flow, they write a script (in Python, Node.js, etc.) that sends the exact same requests. To the grocery store's server, the developer's script looks identical to the official mobile app.

---

## Part 2: The Legality of Calling Private APIs

Is it legal to do this? The answer lies at the intersection of **Copyright Law**, **Contract Law (Terms of Service)**, **Computer Crime Statutes**, and **Data Ownership (GDPR)**. 

If a developer uses reverse engineering to fetch *their own data* (or acts on behalf of a consenting user), the legal landscape looks like this:

### 1. Computer Crime Statutes (Hacking / CFAA)
*   **The Risk:** Laws like the US Computer Fraud and Abuse Act (CFAA) or equivalent European cybercrime laws penalize "unauthorized access" to computer systems.
*   **The Precedent:** Recent rulings (like *Van Buren v. United States* and *hiQ v. LinkedIn*) establish a "gates-up-or-down" policy. If you bypass a technical barrier (like guessing passwords or hacking encryption), it is a crime. However, if a user provides their *own, valid login credentials* to a third-party aggregator, the third-party is acting as an authorized agent of the account owner. Accessing the data with valid credentials is generally not considered "unauthorized access" under criminal hacking laws.

### 2. Copyright Law and Interoperability
*   **The Risk:** Decompiling an app involves making a copy of copyrighted code.
*   **The Precedent:** Both the US and the EU have strong protections for reverse-engineering when the goal is **interoperability**. 
    *   In the EU, the **Software Directive (2009/24/EC) Article 6** explicitly permits decompiling software if it is "indispensable to obtain the information necessary to achieve interoperability" between independent programs.

### 3. Terms of Service (Breach of Contract)
*   **The Risk:** Almost all grocery apps have Terms of Service (ToS) that explicitly forbid "reverse engineering," "scraping," or "automated access." 
*   **The Reality:** Violating the ToS is a civil matter (Breach of Contract), not a criminal one. The grocery chain's primary recourse is to block the IP address or terminate the user's account.
*   **The Exception:** In the EU, the Software Directive dictates that any contractual provision (ToS) that tries to prevent reverse-engineering for the sake of interoperability is **null and void**.

### 4. The GDPR "Trump Card": Data Portability
For services operating in Europe (like WhatIBuy and Kassal.app), **GDPR Article 20 (Right to Data Portability)** is the strongest legal defense.
*   Article 20 gives users the right to retrieve their personal data (like their shopping receipts) in a machine-readable format and move it to another service **"without hindrance."**
*   When aggregators reverse-engineer private APIs, they argue they are acting as the user's technical proxy to exercise their GDPR rights.
*   If a grocery chain aggressively blocks a user-consented aggregator from fetching receipts, the aggregator can argue that the grocery chain is unlawfully "hindering" the user's right to data portability. EU regulators (like the French CNIL) have increasingly taken the stance that platforms should not use technical blocks to prevent users from accessing their own data.

## Summary

When an individual or service uses reverse engineering and private APIs to access their own (or a consenting user's) grocery data:
1.  **Criminal Liability (Hacking):** Very Low (access uses valid, authorized user credentials).
2.  **Copyright Liability:** Low (protected by interoperability exceptions).
3.  **Civil Liability (ToS Violation):** Moderate to High, but strongly mitigated in Europe by GDPR Data Portability rights and the EU Software Directive. The most common outcome is a technical cat-and-mouse game (rate limiting, IP blocking), rather than lawsuits.
