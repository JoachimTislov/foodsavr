(function () {
  var cfg = {
    environment: 'development',
    androidUrl: '',
    contactEmail: 'dev.joachim.tislov@gmail.com',
  };
  window.__FOODSAVR_LANDING__ = cfg;

  var root = document.documentElement;
  root.dataset.env = cfg.environment || 'production';
  if (cfg.androidUrl) {
    root.dataset.androidUrl = cfg.androidUrl;
  } else {
    delete root.dataset.androidUrl;
  }

  try {
    var params = new URLSearchParams(window.location.search);
    var queryLang = params.get('lang');
    var storedLang = window.localStorage.getItem('foodsavr_landing_lang');
    var navLang = (navigator.language || '').toLowerCase();
    var lang =
      queryLang === 'nb' || queryLang === 'en'
        ? queryLang
        : storedLang === 'nb' || storedLang === 'en'
          ? storedLang
          : navLang.startsWith('nb') || navLang.startsWith('nn') || navLang.startsWith('no')
            ? 'nb'
            : 'en';
    root.lang = lang;
    root.dataset.lang = lang;
  } catch (_) {
    root.lang = 'en';
    root.dataset.lang = 'en';
  }
})();
