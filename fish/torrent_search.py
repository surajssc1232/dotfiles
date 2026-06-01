import sys, requests
def search_torrents():
    if len(sys.argv) < 2: return
    query = ' '.join(sys.argv[1:]).replace(' ', '-').lower()
    url = f'https://strem.fun{query}.json'
    try:
        res = requests.get(url, timeout=10).json()
        for item in res.get('streams', []):
            title_text = item.get('title', 'Unknown Title').replace('\n', ' | ')
            magnet = item.get('infoHash', '')
            if magnet:
                full_magnet = f'magnet:?xt=urn:btih:{magnet}'
                print(f'{title_text} \t{full_magnet}')
    except Exception as e:
        pass
if __name__ == '__main__':
    search_torrents()
