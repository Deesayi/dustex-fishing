// DUSTEX Fishing Forecaster service worker: keeps the app shell on the iPad so it opens offline.
// Live data (weather, seas, tides) always goes to the network.
const CACHE = 'dxfish-v13';
const SHELL = ['./', 'index.html', 'manifest.webmanifest', 'gauge_face.png', 'gauge_glass.png', 'gauge_logo.png',
  'apple-touch-icon.png', 'icon-192.png', 'icon-512.png', 'knob.png', 'dustex_logo.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k.startsWith('dxfish-') && k !== CACHE)   /* only this app's old caches: the Tab app shares the site */.map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (u.origin !== location.origin) return;            // APIs: straight to the network
  // app files: network first (so updates show up), cached copy when offline
  e.respondWith(fetch(e.request).then(r => {
    const copy = r.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); return r;
  }).catch(() => caches.match(e.request).then(r => r || caches.match('index.html'))));
});
