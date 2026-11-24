(function () {
  var TRANSLATIONS = {
    en: {
      'meta.title': 'FoodSavr — Track food inventory, scan receipts, reduce waste',
      'meta.description':
        'Track food inventory and expiry dates, scan barcodes and receipts, manage shopping lists, and reduce food waste with FoodSavr.',
      'skip.content': 'Skip to content',
      'env.notice':
        'Test environment — tester terms apply and test data may be wiped.',
      'env.termsLink': 'Read Terms of Service',
      'nav.features': 'Features',
      'nav.plans': 'Plans',
      'nav.privacy': 'Privacy & Account',
      'nav.openApp': 'Open the app',
      'lang.label': 'Language',
      'hero.eyebrow': 'Zero-waste kitchen tracker',
      'hero.title': 'Know what is in your kitchen before it expires.',
      'hero.lead':
        'FoodSavr helps you track food inventory and expiry dates, scan receipts and barcodes, manage shopping lists, and reduce waste across your home.',
      'hero.openApp': 'Open the app',
      'hero.downloadAndroid': 'Download for Android',
      'hero.seePlans': 'Compare plans',
      'hero.note':
        'Free core app on web and Android. Scan photos are deleted right after scanning.',
      'preview.title': 'My Inventory',
      'preview.chip': 'Expiring Soon',
      'preview.item1.name': 'Whole Milk',
      'preview.item1.loc': 'Fridge · 1 L',
      'preview.item1.status': 'Expires today',
      'preview.item2.name': 'Greek Yogurt',
      'preview.item2.loc': 'Fridge · 2 units',
      'preview.item2.status': '2 days left',
      'preview.item3.name': 'Rolled Oats',
      'preview.item3.loc': 'Pantry · 1 unit',
      'preview.item3.status': 'Fresh',
      'preview.footerLeft': 'Shopping List · 4 items ready',
      'preview.footerRight': 'Scan Barcode · Scan Receipt',
      'features.title': 'Everything you need to cut food waste',
      'features.subtitle':
        'Built around fast capture and clear expiry views so nothing gets forgotten in the back of the fridge.',
      'features.inventory.title': 'Track food inventory & expiry',
      'features.inventory.desc':
        'Organize inventories for your fridge, freezer, and pantry. Spot expiring soon items early and get local expiry reminders.',
      'features.scan.title': 'Scan receipts & barcodes',
      'features.scan.desc':
        'Scan barcodes with Open Food Facts enrichment or scan paper receipts on-device with per-item confirmation.',
      'features.shopping.title': 'Shopping lists',
      'features.shopping.desc':
        'Keep shopping lists alongside your inventory and move items between storage locations with bulk actions and undo.',
      'features.waste.title': 'Reduce waste & save money',
      'features.waste.desc':
        'Get meal suggestions from what you already have and follow monthly used versus thrown away insights.',
      'plans.title': 'Simple plans built around your household',
      'plans.subtitle':
        'Start free with everything needed to track food. Paid automation and cloud plans are coming soon — listed below as starting NOK estimates.',
      'plans.billingLabel': 'Billing interval',
      'plans.annual': 'Annual (recommended)',
      'plans.monthly': 'Monthly',
      'plans.badge.live': 'Available now',
      'plans.badge.soon': 'Coming soon',
      'plans.free.name': 'Free',
      'plans.free.price': '0 NOK',
      'plans.free.period': 'forever',
      'plans.free.desc':
        'The standard app for everyday inventory, scanning, and waste reduction.',
      'plans.free.f1': 'Up to 3 inventories, 200 items per inventory',
      'plans.free.f2': 'Share 1 inventory with 1 other person',
      'plans.free.f3':
        'Barcode & on-device receipt scanning with per-item confirmation',
      'plans.free.f4':
        'Expiry tracking, reminders, basic insights, and meal suggestions',
      'plans.free.f5': 'Bulk actions with undo, plus full data export & deletion',
      'plans.plus.name': 'Plus',
      'plans.plus.desc':
        'Unlimited storage plus your choice of 2 paid on-device automation modules.',
      'plans.plus.f1': 'Unlimited inventories and items',
      'plans.plus.f2': 'Pick 2 paid on-device automation modules (swap monthly)',
      'plans.plus.f3': '14-day free trial per module, no card required',
      'plans.plus.f4': 'Share 1 inventory with 1 other person',
      'plans.pro.name': 'Pro',
      'plans.pro.desc':
        'Every automation module plus cloud grocery sync and receipt reading.',
      'plans.pro.f1': 'Unlimited inventories and items',
      'plans.pro.f2': 'All 5 paid on-device automation modules included',
      'plans.pro.f3': 'Cloud modules: store purchase sync & cloud receipt reading',
      'plans.pro.f4': 'Household for 1 or 2 members',
      'plans.family.name': 'Family',
      'plans.family.desc':
        'Shared household automation and cloud modules for the whole family.',
      'plans.family.f1': 'Everything in Pro',
      'plans.family.f2': 'Household for up to 6 members',
      'plans.family.f3': 'Shared household rules with per-member overrides',
      'plans.family.f4': 'Adult-consented invites for members aged 13–17',
      'plans.modules.onDeviceTitle': 'Paid on-device automation modules (Coming soon)',
      'plans.modules.onDeviceDesc':
        'Included in Pro and Family, or pick any 2 in Plus. Each module includes a one-time 14-day trial.',
      'plans.modules.rules': 'Custom rules',
      'plans.modules.autoList': 'Auto shopping list',
      'plans.modules.smartExpiry': 'Smart expiry',
      'plans.modules.advInsights': 'Waste & spend trends',
      'plans.modules.autoAccept': 'Auto-accept ingestion',
      'plans.modules.cloudTitle': 'Cloud modules (Pro & Family · Coming soon)',
      'plans.modules.cloudDesc':
        'Server-powered sync that launches with cloud billing. Paid plans are not live yet.',
      'plans.modules.storeSync': 'Store purchase sync',
      'plans.modules.cloudReceipt': 'Cloud receipt reading',
      'plans.footnote':
        'Viewing, exporting, and deleting your own data is never gated behind a plan. Scan photos are deleted after scanning.',
      'trust.title': 'Privacy, terms & your account',
      'trust.subtitle':
        'Clear documentation and direct self-service routes for your legal rights and account data.',
      'trust.privacy.title': 'Privacy Notice',
      'trust.privacy.desc':
        'Read what data FoodSavr stores, which processors are used, and how to contact the operator with data requests.',
      'trust.privacy.link': 'View Privacy Notice',
      'trust.terms.title': 'Terms of Service',
      'trust.terms.desc':
        'Review the terms governing use of FoodSavr, age requirements (18+, or 13–17 under guardian consent), and Norwegian law.',
      'trust.terms.link': 'View Terms of Service',
      'trust.delete.title': 'Delete Account',
      'trust.delete.desc':
        'Permanently delete your account, inventories, collections, and preferences at any time.',
      'trust.delete.link': 'Go to Delete Account',
      'cta.title': 'Ready to waste less food?',
      'cta.desc':
        'Open FoodSavr in your browser or install it as a web app in seconds.',
      'footer.operator':
        'Operated by the FoodSavr owner as a private person under Norwegian law and the GDPR.',
      'footer.contactPrefix': 'Privacy & data requests:',
      'footer.privacy': 'Privacy Notice',
      'footer.terms': 'Terms of Service',
      'footer.delete': 'Delete Account',
      'footer.openApp': 'Open the app',
    },
    nb: {
      'meta.title': 'FoodSavr — Spor matlager, skann kvitteringer, reduser matsvinn',
      'meta.description':
        'Hold oversikt over matlager og utløpsdatoer, skann strekkoder og kvitteringer, administrer handlelister og reduser matsvinn med FoodSavr.',
      'skip.content': 'Hopp til innhold',
      'env.notice':
        'Testmiljø — testvilkår gjelder og testdata kan bli slettet.',
      'env.termsLink': 'Les vilkår for bruk',
      'nav.features': 'Funksjoner',
      'nav.plans': 'Planer',
      'nav.privacy': 'Personvern og konto',
      'nav.openApp': 'Åpne appen',
      'lang.label': 'Språk',
      'hero.eyebrow': 'Matsvinn-app for kjøkkenet',
      'hero.title': 'Hold oversikt over kjøkkenet før maten går ut på dato.',
      'hero.lead':
        'FoodSavr hjelper deg med å spore matvarer og utløpsdatoer, skanne kvitteringer og strekkoder, holde orden på handlelister og redusere matsvinn hjemme.',
      'hero.openApp': 'Åpne appen',
      'hero.downloadAndroid': 'Last ned for Android',
      'hero.seePlans': 'Se planer',
      'hero.note':
        'Gratis kjerneapp på nett og Android. Skannebilder slettes rett etter skanning.',
      'preview.title': 'Mitt lager',
      'preview.chip': 'Utløper snart',
      'preview.item1.name': 'Helmelk',
      'preview.item1.loc': 'Kjøleskap · 1 l',
      'preview.item1.status': 'Utløper i dag',
      'preview.item2.name': 'Gresk yoghurt',
      'preview.item2.loc': 'Kjøleskap · 2 enheter',
      'preview.item2.status': '2 dager igjen',
      'preview.item3.name': 'Havregryn',
      'preview.item3.loc': 'Matskap · 1 enhet',
      'preview.item3.status': 'Frisk',
      'preview.footerLeft': 'Handleliste · 4 varer klare',
      'preview.footerRight': 'Skann strekkode · Skann kvittering',
      'features.title': 'Alt du trenger for å redusere matsvinn',
      'features.subtitle':
        'Laget for rask registrering og tydelige utløpsoversikter, så ingenting blir glemt innerst i kjøleskapet.',
      'features.inventory.title': 'Lager og utløpsdatoer',
      'features.inventory.desc':
        'Organiser lagre for kjøleskap, fryser og matskap. Se hvilke varer som utløper snart og få lokale påminnelser.',
      'features.scan.title': 'Skann kvitteringer og strekkoder',
      'features.scan.desc':
        'Skann strekkoder med oppslag mot Open Food Facts, eller skann papirkvitteringer på enheten med bekreftelse per vare.',
      'features.shopping.title': 'Handlelister',
      'features.shopping.desc':
        'Hold handlelister samlet med beholdningen og flytt varer mellom lagre med massehandlinger og angring.',
      'features.waste.title': 'Reduser matsvinn og spar penger',
      'features.waste.desc':
        'Få måltidsforslag basert på det du allerede har, og følg månedlig oversikt over brukt kontra kastet mat.',
      'plans.title': 'Enkle planer for hele husholdningen',
      'plans.subtitle':
        'Start gratis med alt du trenger for å spore mat. Betalte automatiserings- og skyplaner kommer snart — oppført med veiledende NOK-priser.',
      'plans.billingLabel': 'Fakturering',
      'plans.annual': 'Årlig (anbefalt)',
      'plans.monthly': 'Månedlig',
      'plans.badge.live': 'Tilgjengelig nå',
      'plans.badge.soon': 'Kommer snart',
      'plans.free.name': 'Gratis',
      'plans.free.price': '0 kr',
      'plans.free.period': 'alltid',
      'plans.free.desc':
        'Standardappen for daglig lageroversikt, skanning og mindre matsvinn.',
      'plans.free.f1': 'Opptil 3 lagre, 200 varer per lager',
      'plans.free.f2': 'Del 1 lager med 1 annen person',
      'plans.free.f3':
        'Strekkode- og kvitteringsskanning på enheten med bekreftelse per vare',
      'plans.free.f4':
        'Utløpssporing, påminnelser, enkel innsikt og måltidsforslag',
      'plans.free.f5':
        'Massehandlinger med angring, samt full eksport og sletting av data',
      'plans.plus.name': 'Plus',
      'plans.plus.desc':
        'Ubegrenset lagring og valg av 2 betalte automatiseringsmoduler på enheten.',
      'plans.plus.f1': 'Ubegrenset antall lagre og varer',
      'plans.plus.f2': 'Velg 2 automatiseringsmoduler på enheten (bytt månedlig)',
      'plans.plus.f3': '14 dagers gratis prøveperiode per modul, uten kort',
      'plans.plus.f4': 'Del 1 lager med 1 annen person',
      'plans.pro.name': 'Pro',
      'plans.pro.desc':
        'Alle automatiseringsmoduler pluss skysynkronisering av kjøp og kvitteringslesing.',
      'plans.pro.f1': 'Ubegrenset antall lagre og varer',
      'plans.pro.f2': 'Alle 5 automatiseringsmoduler på enheten inkludert',
      'plans.pro.f3':
        'Skymoduler: synkronisering av butikkjøp og skybasert kvitteringslesing',
      'plans.pro.f4': 'Husholdning for 1 eller 2 medlemmer',
      'plans.family.name': 'Family',
      'plans.family.desc':
        'Delt husholdningsautomatisering og skymoduler for hele familien.',
      'plans.family.f1': 'Alt i Pro',
      'plans.family.f2': 'Husholdning for opptil 6 medlemmer',
      'plans.family.f3': 'Delte husholdningsregler med individuelle unntak',
      'plans.family.f4': 'Invitasjon for medlemmer 13–17 år med foresattes samtykke',
      'plans.modules.onDeviceTitle':
        'Betalte automatiseringsmoduler på enheten (Kommer snart)',
      'plans.modules.onDeviceDesc':
        'Inkludert i Pro og Family, eller velg 2 i Plus. Hver modul har én 14-dagers prøveperiode.',
      'plans.modules.rules': 'Egne regler',
      'plans.modules.autoList': 'Automatisk handleliste',
      'plans.modules.smartExpiry': 'Smart utløpsdato',
      'plans.modules.advInsights': 'Svinn- og forbrukstrender',
      'plans.modules.autoAccept': 'Autogodkjenning ved skanning',
      'plans.modules.cloudTitle': 'Skymoduler (Pro og Family · Kommer snart)',
      'plans.modules.cloudDesc':
        'Servertjenester som lanseres sammen med betalte planer. Betalte planer er ikke aktive ennå.',
      'plans.modules.storeSync': 'Synkronisering av butikkjøp',
      'plans.modules.cloudReceipt': 'Skybasert kvitteringslesing',
      'plans.footnote':
        'Visning, eksport og sletting av egne data låses aldri bak et abonnement. Skannebilder lagres aldri.',
      'trust.title': 'Personvern, vilkår og kontoen din',
      'trust.subtitle':
        'Tydelig dokumentasjon og direkte selvbetjening for personvernrettigheter og kontodata.',
      'trust.privacy.title': 'Personvernerklæring',
      'trust.privacy.desc':
        'Les hvilke opplysninger FoodSavr lagrer, hvilke databehandlere som brukes, og hvordan du kontakter ansvarlig.',
      'trust.privacy.link': 'Les personvernerklæring',
      'trust.terms.title': 'Vilkår for bruk',
      'trust.terms.desc':
        'Se vilkår for bruk av FoodSavr, aldersgrenser (18 år, eller 13–17 med foresattes samtykke) og norsk lov.',
      'trust.terms.link': 'Les vilkår for bruk',
      'trust.delete.title': 'Slett konto',
      'trust.delete.desc':
        'Slett kontoen din, varelagrene, samlingene og innstillingene dine permanent når som helst.',
      'trust.delete.link': 'Gå til slett konto',
      'cta.title': 'Klar for mindre matsvinn?',
      'cta.desc':
        'Åpne FoodSavr i nettleseren eller installer den som nettapp på sekunder.',
      'footer.operator':
        'FoodSavr drives av eieren som privatperson under norsk lov og personvernforordningen (GDPR).',
      'footer.contactPrefix': 'Personvern og dataforespørsler:',
      'footer.privacy': 'Personvernerklæring',
      'footer.terms': 'Vilkår for bruk',
      'footer.delete': 'Slett konto',
      'footer.openApp': 'Åpne appen',
    },
  };

  var PLAN_PRICES = {
    annual: {
      en: {
        plus: { price: '199 NOK', period: '/ year' },
        pro: { price: '349 NOK', period: '/ year' },
        family: { price: '499 NOK', period: '/ year' },
      },
      nb: {
        plus: { price: '199 kr', period: '/ år' },
        pro: { price: '349 kr', period: '/ år' },
        family: { price: '499 kr', period: '/ år' },
      },
    },
    monthly: {
      en: {
        plus: { price: '25 NOK', period: '/ month' },
        pro: { price: '45 NOK', period: '/ month' },
        family: { price: '59 NOK', period: '/ month' },
      },
      nb: {
        plus: { price: '25 kr', period: '/ mnd' },
        pro: { price: '45 kr', period: '/ mnd' },
        family: { price: '59 kr', period: '/ mnd' },
      },
    },
  };

  var state = {
    lang: document.documentElement.dataset.lang === 'nb' ? 'nb' : 'en',
    billing: 'annual',
  };

  function applyPrices() {
    var set = PLAN_PRICES[state.billing][state.lang];
    var keys = ['plus', 'pro', 'family'];
    for (var i = 0; i < keys.length; i++) {
      var id = keys[i];
      var priceEl = document.querySelector('[data-plan-price="' + id + '"]');
      var periodEl = document.querySelector('[data-plan-period="' + id + '"]');
      if (priceEl) priceEl.textContent = set[id].price;
      if (periodEl) periodEl.textContent = set[id].period;
    }

    var billingButtons = document.querySelectorAll('[data-billing]');
    for (var j = 0; j < billingButtons.length; j++) {
      var btn = billingButtons[j];
      btn.setAttribute(
        'aria-pressed',
        btn.getAttribute('data-billing') === state.billing ? 'true' : 'false',
      );
    }
  }

  function applyLanguage(lang) {
    state.lang = lang === 'nb' ? 'nb' : 'en';
    var dict = TRANSLATIONS[state.lang];
    document.documentElement.lang = state.lang;
    document.documentElement.dataset.lang = state.lang;
    document.title = dict['meta.title'];

    var desc = document.querySelector('meta[name="description"]');
    if (desc) desc.setAttribute('content', dict['meta.description']);

    var nodes = document.querySelectorAll('[data-i18n]');
    for (var i = 0; i < nodes.length; i++) {
      var key = nodes[i].getAttribute('data-i18n');
      if (Object.prototype.hasOwnProperty.call(dict, key)) {
        nodes[i].textContent = dict[key];
      }
    }

    var attrNodes = document.querySelectorAll('[data-i18n-aria-label]');
    for (var j = 0; j < attrNodes.length; j++) {
      var akey = attrNodes[j].getAttribute('data-i18n-aria-label');
      if (Object.prototype.hasOwnProperty.call(dict, akey)) {
        attrNodes[j].setAttribute('aria-label', dict[akey]);
      }
    }

    var langButtons = document.querySelectorAll('[data-lang-btn]');
    for (var k = 0; k < langButtons.length; k++) {
      var btn = langButtons[k];
      btn.setAttribute(
        'aria-pressed',
        btn.getAttribute('data-lang-btn') === state.lang ? 'true' : 'false',
      );
    }

    applyPrices();
  }

  function applyRuntimeConfig() {
    var cfg = window.__FOODSAVR_LANDING__ || {};
    var androidLinks = document.querySelectorAll('[data-android-link]');
    if (cfg.androidUrl) {
      for (var i = 0; i < androidLinks.length; i++) {
        androidLinks[i].setAttribute('href', cfg.androidUrl);
      }
    }
    var emailEl = document.querySelector('[data-contact-email]');
    if (emailEl && cfg.contactEmail) {
      emailEl.textContent = cfg.contactEmail;
      emailEl.setAttribute('href', 'mailto:' + cfg.contactEmail);
    }
  }

  function bindEvents() {
    var langButtons = document.querySelectorAll('[data-lang-btn]');
    for (var i = 0; i < langButtons.length; i++) {
      langButtons[i].addEventListener('click', function (e) {
        var next = e.currentTarget.getAttribute('data-lang-btn');
        try {
          window.localStorage.setItem('foodsavr_landing_lang', next);
        } catch (_) {}
        applyLanguage(next);
      });
    }

    var billingButtons = document.querySelectorAll('[data-billing]');
    for (var j = 0; j < billingButtons.length; j++) {
      billingButtons[j].addEventListener('click', function (e) {
        state.billing = e.currentTarget.getAttribute('data-billing');
        applyPrices();
      });
    }
  }

  window.__foodsavrLanding = {
    translations: TRANSLATIONS,
    setLanguage: applyLanguage,
  };

  applyRuntimeConfig();
  applyLanguage(state.lang);
  bindEvents();
})();
