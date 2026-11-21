/// Remove incompatible FlutterFire settings before Firebase restores App Check.
void migrateAppCheckSettings(
  String? Function(String) read,
  void Function(String) remove, {
  required String? enterpriseSiteKey,
}) {
  const typeKey = 'FlutterFire-[DEFAULT]-recaptchaType';
  const siteKey = 'FlutterFire-[DEFAULT]-recaptchaSiteKey';
  if (enterpriseSiteKey != null &&
      read(typeKey) == 'enterprise' &&
      read(siteKey) == enterpriseSiteKey) {
    return;
  }
  remove(typeKey);
  remove(siteKey);
}
