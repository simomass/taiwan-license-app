import requests
import json
import re

url = "https://space2.thb.gov.tw/d/s/x6B158bsTx3Hlx20WueVCeE1aXHnYEUP/nq4rTikLIfuILf17EUOYwaXYjxOBJkso-bc7gpE5OGgs"
r = requests.get(url)

html = r.text
match = re.search(r'window\.INITIAL_STATE\s*=\s*(\{.*?\});', html)
if match:
    state_str = match.group(1)
    state = json.loads(state_str)
    print("Found INITIAL_STATE!")
    # Try to find the sharing token and file ID
else:
    print("INITIAL_STATE not found.")
    
# Or maybe the token is in window.SYNO_CONFIG
match2 = re.search(r'window\.SYNO_SHARE_CONFIG\s*=\s*(\{.*?\});', html)
if match2:
    print("Found SYNO_SHARE_CONFIG")
    config = json.loads(match2.group(1))
    print(config.keys())
    if "sharing_token" in config:
        print("Token:", config["sharing_token"][:20] + "...")
