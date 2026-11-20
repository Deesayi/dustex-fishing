// DUSTEX Tab offline cache: the app works without internet once installed; updates arrive the next time it opens online.
const CACHE = 'dxtab-v11';
const FILES = ['./', 'index.html', 'logo.png', 'dustex_logo.png', 'looper-worklet.js', 'manifest.webmanifest', 'icon-192.png', 'icon-512.png', 'icon-maskable-512.png', 'icon-180.png', 'favicon.ico', 'gauge_face.png', 'gauge_glass.png', 'gauge_logo.png', 'knob_rot.png', 'fader_cap.png', 'fonts/great-vibes-latin-400-normal.woff2',
  'vendor/basic-pitch.bundle.js', 'vendor/model/model.json', 'vendor/model/group1-shard1of1.bin'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k.startsWith('dxtab-') && k !== CACHE)   /* only this app's old caches: the Fishing app shares the site */.map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const req = e.request; if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return;
  if (req.mode === 'navigate' || req.url.endsWith('index.html')) {          // the page: newest when online, cached when not
    e.respondWith(fetch(req).then(r => { const cp = r.clone(); caches.open(CACHE).then(c => c.put('index.html', cp)); return r; }).catch(() => caches.match('index.html')));
    return;
  }
  e.respondWith(caches.match(req).then(hit => hit || fetch(req).then(r => { if (r.ok) { const cp = r.clone(); caches.open(CACHE).then(c => c.put(req, cp)); } return r; })));
});
