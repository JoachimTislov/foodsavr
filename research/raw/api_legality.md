# Legal Context of Reverse Engineering and Private APIs

## Core Legal Frameworks

The legality of reverse engineering private or undocumented APIs is a complex intersection of **Copyright Law**, **Contract Law (Terms of Service)**, and **Computer Crime Statutes**. While generally permissible for the purpose of **interoperability**, the legal risk increases significantly when bypassing technical security measures or competing directly with the original service.

### 1. Copyright Law and Interoperability
*   **US (Fair Use & DMCA):** The Supreme Court ruling in **Google v. Oracle (2021)** established that reimplementing API "declaring code" for interoperability is generally Fair Use. Additionally, Section 1201(f) of the DMCA provides a "safe harbor" for reverse engineering to achieve interoperability between independently created programs, though it doesn't protect tools meant primarily to circumvent copyright.
*   **EU (Software Directive 2009/24/EC):** Article 6 explicitly permits decompilation if it is "indispensable to obtain the information necessary to achieve the interoperability." Crucially, the Directive states that **contractual provisions (like Terms of Service) contrary to this right are null and void**.

### 2. Contract Law & Terms of Service (ToS)
Most software, including mobile apps like Rema 1000's Æ or Coop, includes a "No Reverse Engineering" or "No Automated Access/Scraping" clause in their ToS.
*   In the US, courts often uphold these as binding contracts. Violating them can lead to **civil breach of contract** claims.
*   However, in the EU, if the reverse engineering is strictly for interoperability, statutory rights can override the ToS.

### 3. Computer Crime Statutes (e.g., CFAA)
The highest risk in using private APIs involves "unauthorized access."
*   **Van Buren v. United States (2021) & hiQ Labs v. LinkedIn (2022):** The US courts have narrowed the Computer Fraud and Abuse Act (CFAA), establishing a "gates-up-or-down" inquiry. Violating a ToS doesn't automatically mean "unauthorized access" if there are no technical barriers.
*   **Private APIs vs. Undocumented APIs:** An undocumented API (open but not publicized) has lower risk. However, a private API protected by "secret handshakes," proprietary encryption, or authentication tokens (like those in grocery apps) is different. Bypassing these "gates" without permission can trigger criminal hacking charges. However, if a user provides their *own* credentials to a third-party app, the third-party app acts as an authorized agent.

## The GDPR Angle: Data Portability

Using scraping or private APIs often intersects with user data rights.

### The Right to Data Portability (GDPR Article 20)
Article 20 grants individuals the right to receive personal data they have provided in a "structured, commonly used, and machine-readable format" and transmit it to another service **"without hindrance."**
*   **The Conflict:** Services like WhatIBuy ask for user consent to fetch grocery receipts. The grocery chains block this, citing security and ToS. The aggregator argues that by blocking them, the grocery chain is creating a "hindrance" to the user's Article 20 rights.
*   **Technical Feasibility:** Article 20(2) states data should be transmitted directly "where technically feasible." The very existence of a private API (used by the mobile app) proves technical feasibility, making it harder for platforms to argue that direct transmission is impossible.
*   **EU Regulators:** Bodies like the French CNIL have noted that technical blocks shouldn't be used to prevent users from accessing their own data. New laws like the **Digital Markets Act (DMA)** are pushing further toward mandated interoperability.

## Conclusion on Legality

If a person (or an aggregator service like WhatIBuy or Kassal.app) reverse-engineers a grocery app to find the API endpoints and then uses their *own* credentials (or credentials explicitly provided by a consenting user) to fetch their *own* data:
1.  **Criminal Liability (CFAA/Hacking):** Low, because the access is authorized by the account owner.
2.  **Copyright Liability:** Low, protected under interoperability exceptions (EU Software Directive / US Fair Use).
3.  **Civil Liability (Breach of ToS):** Moderate to High. The grocery chain can terminate the account or sue for breach of contract, though in the EU, data portability (GDPR) and interoperability laws offer a strong defense.
