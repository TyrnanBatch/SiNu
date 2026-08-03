package com.sinu.sinu

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) so the health plugin can use
// registerForActivityResult when requesting Health Connect permissions.
class MainActivity : FlutterFragmentActivity()
