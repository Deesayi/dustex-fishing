// DUSTEX iPhone + iPad app shell: a full-screen web view of the DUSTEX web app (Creator Studio or Fishing Forecaster).
// The address comes from DXStartURL in Info.plist. The site is an app-bound domain, so its service worker keeps a copy
// for offline use after the first launch. The microphone is offered to the page (Listen) once iOS has asked the user.
import SwiftUI
import WebKit
import AVFoundation

@main
struct DustexApp: App {
    var body: some Scene {
        WindowGroup {
            DustexWebView()
                .ignoresSafeArea()
                .background(Color.black)
                .preferredColorScheme(.dark)
                .statusBarHidden(false)
        }
    }
}

struct DustexWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.limitsNavigationsToAppBoundDomains = true          // lets the site's service worker run (offline copy)
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.uiDelegate = context.coordinator
        web.navigationDelegate = context.coordinator
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.allowsBackForwardNavigationGestures = false
        if #available(iOS 16.4, *) { web.isInspectable = false }
        let session = AVAudioSession.sharedInstance()       // play and listen at the same time (looper, Listen, playback)
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers])
        try? session.setActive(true)
        let start = (Bundle.main.object(forInfoDictionaryKey: "DXStartURL") as? String) ?? "https://deesayi.github.io/dustex-fishing/"
        if let url = URL(string: start) { web.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 20)) }
        context.coordinator.web = web
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        weak var web: WKWebView?

        // Listen / looper / AUX ask for the microphone: allow it (iOS shows its own permission prompt the first time)
        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(origin.host.hasSuffix("github.io") ? .grant : .deny)
        }

        // links to other sites (fishing reports, help links) open in Safari
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = action.request.url, let host = url.host, !host.hasSuffix("github.io"), action.navigationType == .linkActivated {
                UIApplication.shared.open(url); decisionHandler(.cancel); return
            }
            decisionHandler(.allow)
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url { UIApplication.shared.open(url) }
            return nil
        }

        // first launch with no internet: say so instead of a blank screen
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let html = """
            <html><body style="background:#000;color:#d8b46a;font:17px -apple-system;display:flex;align-items:center;justify-content:center;height:100vh;text-align:center">
            <div>D U S T E X<br><br><span style="color:#9a9da6">Connect to the internet once so the app can download itself.<br>After that it works offline.</span></div></body></html>
            """
            webView.loadHTMLString(html, baseURL: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak webView] in webView?.reload() }
        }
    }
}
