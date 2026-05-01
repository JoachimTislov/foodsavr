# How Private APIs Become Accessible

These APIs are not actually "available" or open to the public by design. The grocery chains (Rema 1000, Coop, NorgesGruppen) built them strictly for their own official mobile apps to use. 

However, because of how mobile applications and the internet work, developers can discover and use them through a process called **Reverse Engineering**.

Here is how and why this happens:

## The "How": Reverse Engineering the App

When you install the Æ or Coop app on your phone, the app needs to talk to the store's databases over the internet to fetch your receipts and coupons. Developers figure out how this communication works using a few specific techniques:

### 1. Traffic Interception (Man-in-the-Middle)
Developers route their phone’s internet connection through a proxy tool on their computer (like `mitmproxy`, `Charles Proxy`, or `Proxyman`). This allows them to monitor every single HTTP/HTTPS request the app sends to the server, and every response it gets back. 
*   **Result:** They can see the exact endpoint URLs (e.g., `https://api.rema.no/...`), the headers required, the JSON payload structures, and the authentication tokens.

### 2. Bypassing SSL Pinning
To stop people from snooping on the traffic, companies use "SSL Certificate Pinning" (making the app only trust a specific, hardcoded server certificate). 
*   **The Bypass:** Because the developer physically owns the Android or iOS device, they can "root" or "jailbreak" it. They then use dynamic instrumentation frameworks like **Frida** or **Xposed** to inject code into the running app and disable the SSL pinning checks, allowing the proxy tools to see the traffic again in plain text.

### 3. App Decompilation (Static Analysis)
Developers download the raw Android application package (`.apk` file) and use decompilers (like `jadx` or `apktool`) to turn the compiled app back into readable source code.
*   **Result:** By reading the code, they can find hardcoded secrets. For example, Helge Sverre found Rema's `Ocp-Apim-Subscription-Key` and their OAuth Client ID (`android-251010`) simply by searching through the decompiled text of the Æ app.

### 4. Client Impersonation
Once a developer has the URLs, the required headers, the hidden keys, and understands the login flow, they can write a simple Python or Node.js script that sends the exact same requests. The grocery store's server cannot easily tell the difference between the official iPhone app and a developer's Python script.

---

## The "Why": The Architectural Reality

Why don't the grocery chains just hide or secure them better?

**The Golden Rule of Security: "Never trust the client."**
Because the mobile app runs on the user's physical device, the environment is fundamentally compromised from the company's perspective. 
*   If the app needs a secret key to talk to the server, that key *must* be stored inside the app.
*   If the app needs to authenticate a user, the logic for that authentication *must* exist on the phone.
*   Because all this logic and cryptography exists on a device the user controls, a determined user with the right tools can always extract it.

The only way to truly stop this is through aggressive behavioral analysis on the server side (e.g., blocking IP addresses that make too many requests, looking for subtle differences in how a script handles TCP connections versus how an iPhone does), but this is an ongoing game of cat-and-mouse.
