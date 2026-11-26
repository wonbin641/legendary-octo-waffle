#!/usr/bin/env python3
"""The account server as it runs on Cloudflare, asked from outside: makes one throwaway account, saves, reads back, is
refused a stale save, sets a new password with the recovery code, checks which pages may ask from a browser, and deletes
the account again (nothing is left behind). Standard library only.
Run: python3 test/live.py https://accounts.yarr07.workers.dev [https://the-web-game's-origin]"""
import hashlib, json, secrets, sys, urllib.error, urllib.request

BASE = sys.argv[1].rstrip('/') if len(sys.argv) > 1 else sys.exit(__doc__)
PAGE = sys.argv[2] if len(sys.argv) > 2 else 'https://wonbin641.github.io'
fails = 0

def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + name + (' ' + str(info) if info != '' else ''))
    if not ok: fails += 1

def key_of(i, pw):  # what the game sends for a password
    return hashlib.pbkdf2_hmac('sha256', pw.encode(), ('yarr07:' + i).encode(), 100000, 32).hex()

def call(method, path, body=None, token=None, origin=None):
    q = urllib.request.Request(BASE + path, method=method, data=json.dumps(body).encode() if body is not None else None)
    q.add_header('User-Agent', 'yarr07-live-check')
    if body is not None: q.add_header('Content-Type', 'application/json')
    if token: q.add_header('Authorization', 'Bearer ' + token)
    if origin: q.add_header('Origin', origin)
    try:
        r = urllib.request.urlopen(q, timeout=30); status, text, head = r.status, r.read().decode(), r.headers
    except urllib.error.HTTPError as e:
        status, text, head = e.code, e.read().decode(), e.headers
    try: j = json.loads(text) if text else {}
    except ValueError: j = {}
    return status, j, head

i = 'check_' + secrets.token_hex(4); pw = secrets.token_urlsafe(12); k = key_of(i, pw)
s, j, _ = call('GET', '/')
check('the server answers at its address', s == 200 and j.get('ok') is True and j.get('name') == 'yarr07-accounts', [s, j])
s, j, _ = call('POST', '/register', {'id': i, 'key': k, 'kdf': 1})
tok, code = j.get('token'), j.get('recovery')
check('a new account: a token and a recovery code', s == 201 and bool(tok) and bool(code) and len(code) == 19, s)
try:
    s, j, _ = call('PUT', '/save', {'data': {'v': 4, 'money': 1234, 'cleared': [1]}, 'base': 0}, tok)
    check('its first save is rev 1', s == 200 and j.get('rev') == 1, [s, j])
    s, j, _ = call('POST', '/login', {'id': i.upper(), 'key': k})
    tok2 = j.get('token')
    check('signing in (the id in any case) gives the save back', s == 200 and (j.get('save') or {}).get('rev') == 1 and j['save']['data'].get('money') == 1234, s)
    s, j, _ = call('PUT', '/save', {'data': {'v': 4, 'money': 5000}, 'base': 1}, tok2); r2 = s == 200 and j.get('rev') == 2
    s, j, _ = call('PUT', '/save', {'data': {'v': 4, 'money': 1}, 'base': 1}, tok)
    check('a second device saves (rev 2); the first, not having seen it, is refused with what is there', r2 and s == 409 and (j.get('save') or {}).get('rev') == 2 and j['save']['data'].get('money') == 5000, s)
    s, j, _ = call('POST', '/login', {'id': i, 'key': key_of(i, 'not the password')})
    check('a wrong password is refused', s == 401 and j.get('error') == 'wrong', [s, j])
    s, j, _ = call('GET', '/save'); s2, _, _ = call('GET', '/save', token='A' * 43)
    check('no token, or a made-up one: no save', s == 401 and s2 == 401, [s, s2])
    pw = secrets.token_urlsafe(12); k = key_of(i, pw)
    s, j, _ = call('POST', '/recover', {'id': i, 'recovery': code.lower().replace('-', ' '), 'key': k, 'kdf': 1})
    tok3 = j.get('token'); s2, _, _ = call('GET', '/save', token=tok)
    check('the recovery code sets a new password: a new code, the old sign-ins ended, the save kept', s == 200 and bool(tok3) and j.get('recovery') not in (None, code) and (j.get('save') or {}).get('rev') == 2 and s2 == 401, [s, s2])
    tok = tok3 or tok
    s, j, h = call('OPTIONS', '/login', origin=PAGE); pre = s == 204 and h.get('access-control-allow-origin') == PAGE
    s, j, h = call('POST', '/login', {'id': i, 'key': k}, origin=PAGE); ok_page = s == 200 and h.get('access-control-allow-origin') == PAGE
    tok = j.get('token') or tok
    s, j, h = call('POST', '/login', {'id': i, 'key': k}, origin='https://example.org')
    check("the web game's page may ask from a browser, another site's page gets nothing", pre and ok_page and s == 403 and not h.get('access-control-allow-origin'), [pre, ok_page, s])
finally:
    s, j, _ = call('POST', '/delete', {'key': k}, tok)
    s2, _, _ = call('POST', '/login', {'id': i, 'key': k})
    check('the throwaway account is deleted again, with its save and sign-ins', s == 200 and j.get('ok') is True and s2 == 401, [s, s2])
print('ALL OK' if fails == 0 else '%d FAILED' % fails)
sys.exit(1 if fails else 0)
