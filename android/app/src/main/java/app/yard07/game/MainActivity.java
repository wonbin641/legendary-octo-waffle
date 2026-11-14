package app.yard07.game;

import android.app.Activity;
import android.content.Intent;
import android.widget.Toast;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.Window;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;
import android.webkit.RenderProcessGoneDetail;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/**
 * Hosts the game in a full-screen WebView. All game files ship inside the APK
 * (assets/) and are served from a private https origin, so the game runs offline.
 */
public class MainActivity extends Activity {

    private static final String HOST = "appassets.androidplatform.net";
    private static final String START_URL = "https://" + HOST + "/index.html";

    private WebView web;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Window window = getWindow();
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        setVolumeControlStream(AudioManager.STREAM_MUSIC);

        web = new WebView(this);
        web.setBackgroundColor(0xFF0D1220);
        web.setOverScrollMode(View.OVER_SCROLL_NEVER);
        web.setVerticalScrollBarEnabled(false);
        web.setHorizontalScrollBarEnabled(false);
        web.setHapticFeedbackEnabled(false);
        web.setLongClickable(false);
        web.setOnLongClickListener(new View.OnLongClickListener() {
            @Override
            public boolean onLongClick(View v) {
                return true;
            }
        });

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(false);
        s.setSupportZoom(false);
        s.setBuiltInZoomControls(false);
        s.setDisplayZoomControls(false);
        s.setTextZoom(100);
        s.setUserAgentString(s.getUserAgentString() + " Yard07App/1.0");

        web.setWebChromeClient(new WebChromeClient());
        web.setWebViewClient(new AssetClient());

        setContentView(web);
        hideSystemBars();
        web.loadUrl(START_URL);
    }

    /** Serves https://appassets.androidplatform.net/<path> from the APK's assets folder. */
    private class AssetClient extends WebViewClient {
        @Override
        public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
            Uri url = request.getUrl();
            if (!HOST.equals(url.getHost())) {
                // The game never needs the network; refuse anything else.
                return new WebResourceResponse("text/plain", "utf-8", 403, "Forbidden", noCache(), null);
            }
            String path = url.getPath();
            if (path == null || path.equals("/") || path.isEmpty()) path = "/index.html";
            String asset = path.substring(1);
            try {
                InputStream in = getAssets().open(asset);
                String mime = mimeOf(asset);
                String enc = mime.startsWith("text/") || mime.equals("application/javascript") ? "utf-8" : null;
                return new WebResourceResponse(mime, enc, 200, "OK", noCache(), in);
            } catch (IOException e) {
                return new WebResourceResponse("text/plain", "utf-8", 404, "Not Found", noCache(), null);
            }
        }

        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
            Uri u = request.getUrl();
            if (HOST.equals(u.getHost())) return false;
            // the game's own links that leave it: a mailto (the save code by email, the bug report address) goes to the mail app,
            // a web address (Gmail's compose page) to the browser or the app that handles it; anything else stays blocked
            String scheme = u.getScheme() == null ? "" : u.getScheme().toLowerCase(Locale.ROOT);
            try {
                if (scheme.equals("mailto")) {
                    // the whole mailto (address, subject, body) goes as the data, for mail apps that read it there; the subject and
                    // body also go as extras for the ones that read those (they replace, so nothing doubles). Read from the encoded
                    // text and decoded once here: android.net.MailTo decodes twice, which breaks a body holding % or &
                    Intent i = new Intent(Intent.ACTION_SENDTO, u);
                    String ssp = u.getEncodedSchemeSpecificPart();
                    int q = ssp == null ? -1 : ssp.indexOf('?');
                    if (q >= 0) {
                        for (String kv : ssp.substring(q + 1).split("&")) {
                            int e = kv.indexOf('=');
                            if (e <= 0) continue;
                            String k = Uri.decode(kv.substring(0, e)).toLowerCase(Locale.ROOT), v = Uri.decode(kv.substring(e + 1));
                            if (k.equals("subject")) i.putExtra(Intent.EXTRA_SUBJECT, v);
                            else if (k.equals("body")) i.putExtra(Intent.EXTRA_TEXT, v);
                        }
                    }
                    startActivity(i);
                } else if (scheme.equals("https") || scheme.equals("http")) {
                    startActivity(new Intent(Intent.ACTION_VIEW, u));
                }
            } catch (RuntimeException e) { // ActivityNotFoundException: nothing on the phone takes it
                Toast.makeText(MainActivity.this, scheme.equals("mailto") ? "메일 앱이 없습니다 · 메일 내용 복사를 써 주세요" : "열 수 있는 앱이 없습니다", Toast.LENGTH_LONG).show();
            }
            return true;
        }

        @Override
        public boolean onRenderProcessGone(WebView view, RenderProcessGoneDetail detail) {
            // The page's renderer died (usually low memory): rebuild the screen instead of crashing.
            if (web != null) {
                ((android.view.ViewGroup) web.getParent()).removeView(web);
                web.destroy();
                web = null;
            }
            recreate();
            return true;
        }
    }

    private static Map<String, String> noCache() {
        Map<String, String> h = new HashMap<>();
        h.put("Cache-Control", "no-cache");
        return h;
    }

    private static String mimeOf(String name) {
        if (name.endsWith(".html")) return "text/html";
        if (name.endsWith(".js")) return "application/javascript";
        if (name.endsWith(".css")) return "text/css";
        if (name.endsWith(".woff2")) return "font/woff2";
        if (name.endsWith(".png")) return "image/png";
        if (name.endsWith(".txt")) return "text/plain";
        if (name.endsWith(".json")) return "application/json";
        return "application/octet-stream";
    }

    @SuppressWarnings("deprecation")
    private void hideSystemBars() {
        Window window = getWindow();
        if (Build.VERSION.SDK_INT >= 30) {
            window.setDecorFitsSystemWindows(false);
            WindowInsetsController c = window.getInsetsController();
            if (c != null) {
                c.hide(WindowInsets.Type.systemBars());
                c.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
            }
        } else {
            window.getDecorView().setSystemUiVisibility(
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                            | View.SYSTEM_UI_FLAG_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
        }
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) hideSystemBars();
    }

    /** Back pauses the game (or leaves the pause/result screen); on the title screen it exits. */
    @Override
    @SuppressWarnings("deprecation")
    public void onBackPressed() {
        if (web == null) {
            super.onBackPressed();
            return;
        }
        web.evaluateJavascript("(window.yardBack && window.yardBack()) ? 1 : 0", new ValueCallback<String>() {
            @Override
            public void onReceiveValue(String value) {
                if (!"1".equals(value)) MainActivity.super.onBackPressed();
            }
        });
    }

    @Override
    protected void onPause() {
        if (web != null) {
            web.evaluateJavascript("window.yardPause && window.yardPause()", null);
            web.onPause();
            web.pauseTimers();
        }
        super.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (web != null) {
            web.onResume();
            web.resumeTimers();
        }
        hideSystemBars();
    }

    @Override
    protected void onDestroy() {
        if (web != null) {
            web.destroy();
            web = null;
        }
        super.onDestroy();
    }
}
