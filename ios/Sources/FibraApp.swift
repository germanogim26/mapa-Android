import SwiftUI
import Mobile
import WebKit
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()
    var webView: WKWebView?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func handleLocationRequest() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last, let wv = webView {
            let lat = loc.coordinate.latitude
            let lng = loc.coordinate.longitude
            let acc = loc.horizontalAccuracy
            let js = "if(window.gpsSuccess) { window.gpsSuccess({coords: {latitude: \(lat), longitude: \(lng), accuracy: \(acc)}, timestamp: new Date().getTime()}); }"
            DispatchQueue.main.async { wv.evaluateJavaScript(js, completionHandler: nil) }
            manager.stopUpdatingLocation()
        }
    }
}

struct ContentView: UIViewRepresentable {
    @StateObject var locationManager: LocationManager

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: ContentView
        init(_ parent: ContentView) { self.parent = parent }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "gpsBridge" {
                DispatchQueue.main.async {
                    self.parent.locationManager.handleLocationRequest()
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let clickJS = "setTimeout(function() { var btn = document.querySelector('.leaflet-control-locate a'); if(btn) btn.click(); }, 1000);"
            webView.evaluateJavaScript(clickJS, completionHandler: nil)
        }
    }

    func makeCoordinator() -> Coordinator { return Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "gpsBridge")

        let ponteJS = """
        if (!navigator.geolocation) {
            navigator.geolocation = {};
        }

        navigator.geolocation.getCurrentPosition = function(success, error, options) {
            window.gpsSuccess = success;
            window.webkit.messageHandlers.gpsBridge.postMessage('get');
        };
        navigator.geolocation.watchPosition = function(success, error, options) {
            window.gpsSuccess = success;
            window.webkit.messageHandlers.gpsBridge.postMessage('get');
            return 1;
        };
        navigator.geolocation.clearWatch = function(id) {};

        var style = document.createElement('style');
        style.innerHTML = '* { -webkit-touch-callout: none !important; -webkit-user-select: none !important; }';
        document.head.appendChild(style);
        """
        let script = WKUserScript(source: ponteJS, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        locationManager.webView = webView
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false

        if let url = URL(string: "http://127.0.0.1:5002") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

@main
struct FibraApp: App {
    @StateObject private var locationManager = LocationManager()
    
    init() {
        DispatchQueue.global(qos: .background).async {
            MobileStartServer()
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView(locationManager: locationManager)
                .ignoresSafeArea()
                .preferredColorScheme(.dark)
        }
    }
}
