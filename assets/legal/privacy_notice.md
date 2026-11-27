## Privacy Policy for LettMat

**Last Updated:** November 27, 2026

LettMat (formerly FoodSavr) ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains what personal data we collect, how we use it, and your rights when you use the LettMat web and mobile applications (the "App").

### 1. Operator & Legal Framework

LettMat is operated by its owner as a private person in Norway. Norwegian law and the EU/EEA General Data Protection Regulation (GDPR) apply to the processing of your personal data.

### 2. Information We Collect

**a. Information You Provide:**
* **Account Information:** Email address, display name, and sign-in credentials managed through Firebase Authentication (including optional Google or Facebook sign-in, or anonymous guest sessions).
* **Kitchen & Household Data:** Inventories, shopping lists, product names, quantities, expiry dates, and app preferences stored in Cloud Firestore so your data stays synced across your devices.

**b. Scanning & Third-Party Lookups:**
* **Barcode Lookups:** Scanned barcodes are queried against Open Food Facts to retrieve product metadata.
* **Receipt Scanning:** Receipt photos are processed on-device and are deleted right after scanning.
* **Grocery Store Connections:** If you connect a supported grocery store in the mobile app, connection tokens are stored locally on your device.

**c. Technical & Diagnostic Data:**
* Basic device and runtime error diagnostics needed to keep the App reliable and secure.

### 3. How We Use Your Information

We use your data only to:
* Provide, sync, and maintain your inventories, shopping lists, expiry reminders, and preferences.
* Authenticate your account and protect against unauthorized access or abuse.
* Diagnose bugs and improve the reliability of the App.

We do not sell your personal data.

### 4. Service Providers & Disclosure

We rely on trusted infrastructure providers to operate the App:
* **Google Firebase** (Authentication, Cloud Firestore, Hosting, and App Check) to run sign-in, storage, and security.
* **Open Food Facts** for public barcode product lookups.

We may also disclose information if required by Norwegian or EEA law.

### 5. Data Security & Retention

We apply reasonable technical and organizational safeguards to protect your data. Your data is retained for as long as your account remains active, or until you delete it.

### 6. Your Rights & Deleting Your Account

Under the GDPR, you have the right to access, correct, export, or delete your personal data, and to object to or restrict processing.

You can permanently delete your account, inventories, shopping lists, and preferences at any time from Settings or directly at `/account/delete` (also reachable at `/delete-account`).

### 7. Age Requirements

You must be at least 18 years old to create an account independently, or aged 13–17 with parent or legal guardian consent. LettMat is not intended for children under 13, and we do not knowingly collect personal data from children under 13.

### 8. Changes to This Privacy Policy

We may update this Privacy Policy as LettMat evolves. The latest version is always available in the App and at `/legal/privacy`.

### 9. Contact

For privacy questions or GDPR data requests, contact us at dev.joachim.tislov@gmail.com.
