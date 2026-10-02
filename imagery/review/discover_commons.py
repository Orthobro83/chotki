"""Collect Wikimedia Commons leads for human curation without adding them to Chotki.

Usage: python3 discover_commons.py /private/tmp/chotki-commons-leads.json
The script deliberately retains unselected metadata outside the gallery. Every
image still needs individual rights and visual review before it can be staged.
"""

import json
import os
import sys
import time
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

QUERIES = [
    '"Greek Orthodox" haswbstatement:P275=Q6938433',
    '"Russian Orthodox" haswbstatement:P275=Q6938433',
    '"Eastern Orthodox" haswbstatement:P275=Q6938433',
    '"Orthodox monastery" haswbstatement:P275=Q6938433',
    '"Orthodox cathedral" haswbstatement:P275=Q6938433',
    '"monastery" "Greece" haswbstatement:P275=Q6938433',
    '"Orthodox fresco" haswbstatement:P275=Q6938433',
]
AGENT = 'ChotkiImageResearch/0.1 (https://github.com/Orthobro83/chotki; CC0 image curation)'
API = 'https://commons.wikimedia.org/w/api.php?'


def request(params):
    url = API + urlencode({'action': 'query', 'format': 'json', **params})
    for attempt in range(6):
        try:
            with urlopen(Request(url, headers={'User-Agent': AGENT}), timeout=40) as response:
                result = json.load(response)
            if 'error' in result:
                code = result['error'].get('code', 'unknown')
                if attempt == 5:
                    raise RuntimeError(f'Commons API {code}: {result["error"].get("info", "")}')
                delay = 5 * 2 ** attempt
                print(f'Commons API {code}; waiting {delay}s', file=sys.stderr, flush=True)
                time.sleep(delay)
                continue
            time.sleep(1.25)
            return result
        except HTTPError as error:
            if error.code not in (429, 503) or attempt == 5:
                raise
            delay = max(int(error.headers.get('Retry-After', '0') or '0'), 5 * 2 ** attempt)
            print(f'HTTP {error.code}; waiting {delay}s', file=sys.stderr, flush=True)
            time.sleep(delay)


def main():
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('/private/tmp/chotki-commons-leads.json')
    start_offset = int(os.environ.get('CHOTKI_SEARCH_START_OFFSET', '0'))
    pages_per_query = int(os.environ.get('CHOTKI_SEARCH_PAGES', '2'))
    found = {}
    queries = json.loads(os.environ['CHOTKI_SEARCH_QUERIES']) if 'CHOTKI_SEARCH_QUERIES' in os.environ else QUERIES
    for term in queries:
        for page in range(pages_per_query):
            params = {'list': 'search', 'srnamespace': 6, 'srsearch': term, 'srlimit': 50}
            offset = start_offset + page * 50
            if offset: params['sroffset'] = offset
            result = request(params)
            hits = result['query']['search']
            for hit in hits:
                found.setdefault(hit['title'], set()).add(term)
            print(f'{term}: offset {offset}, {len(hits)} files, {len(found)} distinct', flush=True)
            if not result.get('continue', {}).get('sroffset'): break

    records = []
    titles = list(found)
    for start in range(0, len(titles), 40):
        result = request({'prop': 'imageinfo', 'iiprop': 'extmetadata|url|size|mime',
                          'iiurlwidth': 950, 'titles': '|'.join(titles[start:start + 40])})
        for page in result['query']['pages'].values():
            if 'imageinfo' not in page: continue
            info = page['imageinfo'][0]
            metadata = info.get('extmetadata', {})
            record = {
                'title': page['title'], 'terms': sorted(found.get(page['title'], ())),
                'license': metadata.get('LicenseShortName', {}).get('value', ''),
                'artist': metadata.get('Artist', {}).get('value', ''),
                'source': metadata.get('Credit', {}).get('value', ''),
                'description': metadata.get('ImageDescription', {}).get('value', ''),
                'width': info.get('width', 0), 'height': info.get('height', 0),
                'mime': info.get('mime', ''), 'thumburl': info.get('thumburl', ''),
                'page': 'https://commons.wikimedia.org/wiki/' + page['title'].replace(' ', '_'),
            }
            if record['license'] in {'CC0', 'Public domain'} and record['mime'] in {'image/jpeg', 'image/png'} and min(record['width'], record['height']) >= 1200:
                records.append(record)
        print(f'metadata {min(start + 40, len(titles))}/{len(titles)}; eligible {len(records)}', flush=True)
        output.write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n')
    print(f'Saved {len(records)} eligible leads to {output}', flush=True)


if __name__ == '__main__':
    main()
