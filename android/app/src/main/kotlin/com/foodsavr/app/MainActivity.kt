package com.foodsavr.app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private fun init() {
        Firebase.initialize(context = this)
        Firebase.appCheck.installAppCheckProviderFactory(
            PlayIntegrityAppCheckProviderFactory.getInstance(),
        )
    }

    private fun initDebug() {
        Firebase.initialize(context = this)
        Firebase.appCheck.installAppCheckProviderFactory(
            DebugAppCheckProviderFactory.getInstance(),
        )

    }
}
