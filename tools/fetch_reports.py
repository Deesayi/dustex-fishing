"""DUSTEX Fishing - collects recent local fishing reports into reports.json.

Runs on GitHub Actions every few hours (see .github/workflows/reports.yml).
For each area in reports-places.json it searches Google News and Bing News
for fishing reports, keeps the last few weeks, removes duplicates and saves
title / source / date / link. Standard library only.
"""
import json, re, html, sys, time, urllib.parse, urllib.request
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime
from datetime import datetime, timezone, timedelta

ROOT = sys.argv[1] if len(sys.argv) > 1 else '.'
MAX_AGE_DAYS = 21
MAX_ITEMS = 12
UA = 'Mozilla/5.0 (DUSTEX Fishing report collector)'


def get(url):
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()


def clean(s):
    s = html.unescape(re.sub(r'<[^>]+>', ' ', s or ''))
    return re.sub(r'\s+', ' ', s).strip()


def parse_rss(xml_bytes, default_source):
    out = []
    root = ET.fromstring(xml_bytes)
    for it in root.iter('item'):
        title = clean(it.findtext('title'))
        link = (it.findtext('link') or '').strip()
        src_el = it.find('source')
        source = clean(src_el.text) if src_el is not None and src_el.text else default_source
        # Google News puts " - Source" on the end of titles
        if source and title.endswith(' - ' + source):
            title = title[: -len(source) - 3].strip()
        desc = clean(it.findtext('description'))
        if desc.startswith(title):
            desc = desc[len(title):].strip(' -')
        if source and desc.endswith(source):
            desc = desc[: -len(source)].strip()
        if desc and title.lower().startswith(desc.lower()):
            desc = ''
        try:
            when = parsedate_to_datetime(it.findtext('pubDate')).astimezone(timezone.utc)
        except Exception:
            when = None
        if title and link:
            out.append({'title': title, 'source': source, 'link': link, 'snippet': desc[:300],
                        'date': when.isoformat() if when else None})
    return out


SPECIES = (r'redfish|red drum|snook|trout|seatrout|tarpon|black drum|snapper|grouper|crappie|bass|catfish|walleye|bluegill|sunfish|bream|'
           r'striper|hybrid|salmon|steelhead|perch|pike|musky|muskie|halibut|rockfish|lingcod|tuna|mahi|dolphin|kingfish|king mackerel|'
           r'spanish mackerel|flounder|fluke|tautog|sheepshead|cobia|wahoo|bonefish|permit|bluefish|weakfish|corvina|yellowtail|sturgeon|'
           r'kokanee|whiting|pompano|croaker|spot|sailfish|marlin|amberjack|triggerfish|shark|panfish|white bass|calico')
REPORT = r'fishing report|fish report|fishing roundup|roundup|report|bite|biting|catching|caught|hooked|limits?|anglers? (are|have|report)|on the hook|outlook|forecast'
NOISE = (r'accident|drown|died|death|dead body|missing|rescue|arrest|charged|police|deputy|sheriff|crash|lawsuit|court|tickets? on sale|'
         r'expo|festival|riverfest|fundraiser|obituar|shooting|stabbing|murder|hit-and-run|license plate|recipe|restaurant|real estate|'
         r'for sale|election|council|commission vote')


def is_report(item, words):
    """keep only real fishing reports: a species or bite/catch language, a place from this area, and none of the usual noise"""
    text = (item['title'] + ' ' + item['snippet']).lower()
    if re.search(NOISE, text):
        return False
    where = text + ' ' + (item.get('source') or '').lower()     # the headline, summary or the paper's own name must be local
    if words and not any(w.lower() in where for w in words):
        return False
    species = re.search(SPECIES, text)
    report = re.search(REPORT, text)
    return bool(species and (report or 'fish' in text)) or bool(re.search(r'fishing report|fish report|fishing roundup', text))


def collect(place):
    terms = place['search']
    places = '(' + ' OR '.join(f'"{t}"' for t in terms) + ')'
    q1 = '("fishing report" OR "fishing roundup" OR "fishing forecast") ' + places                                                          # the weekly columns
    q2 = '(fishing OR anglers) (bite OR biting OR catching OR caught) ' + places                # catch news
    gn = lambda q: 'https://news.google.com/rss/search?' + urllib.parse.urlencode({'q': q + f' when:{MAX_AGE_DAYS}d', 'hl': 'en-US', 'gl': 'US', 'ceid': 'US:en'})
    feeds = [
        (gn(q1), 'Google News'),
        (gn(q2), 'Google News'),
        ('https://www.bing.com/news/search?' + urllib.parse.urlencode({'q': f'fishing report {terms[0]}', 'format': 'rss'}), 'Bing News'),
    ]
    items, errors = [], []
    for url, name in feeds:
        try:
            items += parse_rss(get(url), name)
        except Exception as e:
            errors.append(f'{name}: {e}')
        time.sleep(1)
    cutoff = datetime.now(timezone.utc) - timedelta(days=MAX_AGE_DAYS)
    seen, keep = {}, []
    for it in sorted(items, key=lambda x: x['date'] or '', reverse=True):
        key = re.sub(r'[^a-z0-9]', '', it['title'].lower())[:60]
        if key in seen:
            k = seen[key]
            if len(it['snippet']) > len(k['snippet']):
                k['snippet'] = it['snippet']
            continue
        if it['date'] and datetime.fromisoformat(it['date']) < cutoff:
            continue
        if not is_report(it, place.get('must', terms)):
            continue
        seen[key] = it
        keep.append(it)
    return keep[:MAX_ITEMS], errors


def main():
    places = json.load(open(f'{ROOT}/reports-places.json', encoding='utf-8'))
    out = {'updated': datetime.now(timezone.utc).isoformat(timespec='seconds'), 'places': []}
    for p in places:
        items, errs = collect(p)
        out['places'].append({'name': p['name'], 'lat': p['lat'], 'lon': p['lon'], 'items': items, 'errors': errs})
        print(f"{p['name']}: {len(items)} reports" + (f"  ({'; '.join(errs)})" if errs else ''))
    with open(f'{ROOT}/reports.json', 'w', encoding='utf-8') as f:
        json.dump(out, f, indent=1, ensure_ascii=False)


if __name__ == '__main__':
    main()
