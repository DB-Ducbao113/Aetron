import urllib.request
import re
import json

url = "https://zenodo.org/doi/10.5281/zenodo.20525157"
req = urllib.request.Request(url, headers={"User-Agent": "curl/8.7.1"})
try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        final_url = resp.geturl()
        html = resp.read().decode("utf-8")
        print("Final URL:", final_url)
        print("HTML length:", len(html))
        
        # Look for record ID
        rec_id = re.search(r"/records/(\d+)", final_url)
        if rec_id:
            print("Record ID:", rec_id.group(1))
            
        # Search for files in the page JSON or HTML
        files = sorted(list(set(re.findall(r"(/records/\d+/files/[^\"']+\?download=1)", html))))
        print("Unique files count:", len(files))
        for f in files:
            print("  ", f)
            
        # Check for window.__PRELOADED_STATE__ or similar
        preloaded = re.search(r"data-invenio-rdm-record=[\"'](.*?)[\"']", html)
        if preloaded:
            print("Found invenio-rdm-record")
            
        json_matches = re.findall(r'(\{"key":\s*"[^"]+",\s*"size":\s*\d+[^}]*\})', html)
        print("JSON matches count:", len(json_matches))
        for jm in json_matches[:10]:
            print("  ", jm)
except Exception as e:
    print("Error:", e)
