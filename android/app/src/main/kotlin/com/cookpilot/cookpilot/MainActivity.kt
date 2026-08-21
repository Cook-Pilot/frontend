package com.cookpilot.cookpilot

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterActivity 가 아니라 FlutterFragmentActivity 다 — flutter_naver_login 이 Activity 를
// FlutterFragmentActivity 로 캐스팅해 registerForActivityResult 를 쓰므로, FlutterActivity 면
// 플러그인이 붙는 순간(앱 시작) ClassCastException 으로 죽는다.
class MainActivity : FlutterFragmentActivity()
