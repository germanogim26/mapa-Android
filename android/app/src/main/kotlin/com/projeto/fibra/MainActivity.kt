package com.projeto.fibra

import android.app.Activity
import android.os.Bundle
import android.webkit.*
import android.Manifest
import android.content.pm.PackageManager
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import mobile.Mobile

// Mudando para Activity padrão. Zero chance de crash por falta de tema XML.
class MainActivity : Activity() {
    private lateinit var webView: WebView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Inicia o servidor Go em segundo plano protegido contra falhas
        try {
            Thread { 
                try {
                    Mobile.startServer() 
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }.start()
        } catch (e: Exception) {
            Toast.makeText(this, "Iniciando Motor Offline...", Toast.LENGTH_SHORT).show()
        }

        webView = WebView(this)
        setContentView(webView)
        
        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.settings.setGeolocationEnabled(true)

        // A Ponte Camaleão: Ouve as chamadas simuladas do WebKit
        webView.addJavascriptInterface(object {
            @JavascriptInterface
            fun postMessage(message: String) { runOnUiThread { pedirGPS() } }
        }, "AndroidBridge")

        // O Script que engana o HTML fazendo-o achar que está no iOS
        val bridgeJS = "if(!window.webkit) window.webkit = { messageHandlers: { gpsBridge: { postMessage: function(m) { window.AndroidBridge.postMessage(m); } } } };"

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                view?.evaluateJavascript(bridgeJS, null)
                // Clica no botão de GPS após 1.5s automaticamente
                view?.evaluateJavascript("setTimeout(function() { var btn = document.querySelector('.leaflet-control-locate a'); if(btn) btn.click(); }, 1500);", null)
            }
        }
        
        webView.webChromeClient = object : WebChromeClient() {
            override fun onGeolocationPermissionsShowPrompt(origin: String, callback: GeolocationPermissions.Callback) {
                callback.invoke(origin, true, false)
            }
        }

        webView.loadUrl("http://127.0.0.1:5002")
        pedirGPS()
    }

    private fun pedirGPS() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.ACCESS_FINE_LOCATION), 1)
        }
    }
}
