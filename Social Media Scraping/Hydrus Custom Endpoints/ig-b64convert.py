#Script to run on a webserver, takes the shortcode and returns the decoded base64 value that IG is now looking for

import base64
import sys
import cgi
import requests

def shortcode_to_mediaid(self, shortcode):
    return int.from_bytes(base64.urlsafe_b64decode('A' * (12 - len(shortcode)) + shortcode), 'big')

print('Content-Type: application/json')
print('')
args = cgi.parse()
igid = args['igid'][0]
intigid = int.from_bytes(base64.urlsafe_b64decode('A' * (12 - len(igid)) + igid), 'big')
url  = f"https://i.instagram.com/api/v1/media/{intigid}/info/"

print(f'{{"newid":"{intigid}"}}')