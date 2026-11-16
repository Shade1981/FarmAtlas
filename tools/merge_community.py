#!/usr/bin/env python3
"""FarmAtlas community merge tool.

Reads any number of FarmAtlas SavedVariables files
(WTF/Account/<ACCOUNT>/SavedVariables/FarmAtlas.lua) and writes
Data/Community.lua for the next release.

    python3 tools/merge_community.py  file1.lua file2.lua ...  [-o Data/Community.lua]

Every value FarmAtlas stores is an absolute count, so the same player's data
seen in several files (his own file + friends who received it by sync) is
counted once: per player we keep the MAXIMUM, then sum across players.
"""
import argparse, os, re, sys, time

# ---------------------------------------------------------------- Lua parser
TOK = re.compile(r'''\s*(?:
    (?P<comment>--\[(?P<eq>=*)\[.*?\](?P=eq)\]|--[^\n]*) |
    (?P<str>"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*') |
    (?P<num>-?(?:0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+)) |
    (?P<name>[A-Za-z_][A-Za-z0-9_]*) |
    (?P<op>[{}\[\]=,;])
)''', re.X | re.S)

ESC = {'n': '\n', 't': '\t', 'r': '\r', '\\': '\\', '"': '"', "'": "'", '\n': '\n'}

def unquote(s):
    body, out, i = s[1:-1], [], 0
    while i < len(body):
        c = body[i]
        if c == '\\' and i + 1 < len(body):
            n = body[i + 1]
            if n.isdigit():
                m = re.match(r'\d{1,3}', body[i + 1:]).group(0)
                out.append(chr(int(m))); i += 1 + len(m); continue
            out.append(ESC.get(n, n)); i += 2; continue
        out.append(c); i += 1
    return ''.join(out)

def tokenize(src):
    pos, toks = 0, []
    while pos < len(src):
        m = TOK.match(src, pos)
        if not m or m.end() == pos:
            if src[pos:].strip() == '':
                break
            raise ValueError('cannot parse near: %r' % src[pos:pos + 40])
        pos = m.end()
        if m.group('comment'):
            continue
        for kind in ('str', 'num', 'name', 'op'):
            if m.group(kind) is not None:
                toks.append((kind, m.group(kind)))
                break
    return toks

class Parser:
    def __init__(self, toks): self.t, self.i = toks, 0
    def peek(self): return self.t[self.i] if self.i < len(self.t) else (None, None)
    def take(self): tok = self.peek(); self.i += 1; return tok
    def expect(self, v):
        k, x = self.take()
        if x != v: raise ValueError('expected %s got %s' % (v, x))
    def value(self):
        k, v = self.take()
        if k == 'str': return unquote(v)
        if k == 'num': return float.fromhex(v) if 'x' in v.lower() else (float(v) if re.search(r'[.eE]', v) else int(v))
        if k == 'name':
            return {'true': True, 'false': False, 'nil': None}.get(v, v)
        if v == '{': return self.table()
        raise ValueError('unexpected %r' % v)
    def table(self):
        out, idx = {}, 1
        while True:
            k, v = self.peek()
            if v == '}': self.take(); return out
            if v == '[':
                self.take(); key = self.value(); self.expect(']'); self.expect('=')
                out[key] = self.value()
            elif k == 'name' and self.t[self.i + 1][1] == '=':
                self.take(); self.take(); out[v] = self.value()
            else:
                out[idx] = self.value(); idx += 1
            k, v = self.peek()
            if v in (',', ';'): self.take()

def load_saved(path):
    src = open(path, encoding='utf-8', errors='replace').read()
    m = re.search(r'FarmAtlasDB\s*=', src)
    if not m: raise ValueError('%s: no FarmAtlasDB found' % path)
    p = Parser(tokenize(src[m.end():]))
    return p.value()

# ---------------------------------------------------------------- merging
def key_norm(k):
    if isinstance(k, float) and k.is_integer(): return int(k)
    return k

def as_int(v, lo, hi):
    try: v = int(v)
    except (TypeError, ValueError): return None
    return v if lo <= v <= hi else None

def take_player(store, origin, items, kills):
    p = store.setdefault(origin, {'items': {}, 'kills': {}})
    for key, e in (items or {}).items():
        if not isinstance(e, dict): continue
        key = key_norm(key)
        it = p['items'].setdefault(key, {'zones': {}, 'mobs': {}, 'cat': e.get('cat'), 'name': e.get('name')})
        for mapID, cells in (e.get('zones') or {}).items():
            mapID = as_int(mapID, 1, 100000)
            if not mapID or not isinstance(cells, dict): continue
            z = it['zones'].setdefault(mapID, {})
            for ck, c in cells.items():
                if not isinstance(c, dict): continue
                n = as_int(c.get('n'), 1, 1000000)
                x, y = c.get('x'), c.get('y')
                if not n or not isinstance(x, (int, float)) or not isinstance(y, (int, float)): continue
                if not (0 <= x <= 100 and 0 <= y <= 100): continue
                old = z.get(ck)
                if not old or n > old['n']:
                    z[ck] = {'x': round(x, 1), 'y': round(y, 1), 'n': n}
        for npcID, m in (e.get('mobs') or {}).items():
            npcID = as_int(npcID, 1, 9999999)
            if not npcID or not isinstance(m, dict): continue
            n = as_int(m.get('n'), 1, 1000000)
            if not n: continue
            old = it['mobs'].get(npcID)
            if not old or n > old['n']:
                it['mobs'][npcID] = {'n': n, 'lvl': as_int(m.get('lvl'), 1, 63), 'name': m.get('name')}
    for npcID, n in (kills or {}).items():
        npcID, n = as_int(npcID, 1, 9999999), as_int(n, 1, 10000000)
        if npcID and n and n > p['kills'].get(npcID, 0):
            p['kills'][npcID] = n

def merge(files):
    store = {}
    for path in files:
        db = load_saved(path)
        chars = [str(c).split('-', 1)[-1] for c in (db.get('chars') or {})]
        own_origin = chars[0] if chars else os.path.basename(os.path.dirname(os.path.dirname(path))) or path
        aliases = set(chars)
        own = {k: v for k, v in (db.get('learned') or {}).items()
               if isinstance(v, dict) and (v.get('own') or (v.get('total') or 0) > 0)}
        take_player(store, own_origin, own, db.get('kills'))
        for sender, s in (db.get('shared') or {}).items():
            if not isinstance(s, dict): continue
            origin = own_origin if str(sender).split('-')[0] in aliases else str(sender).split('-')[0]
            take_player(store, origin, s.get('items'), s.get('kills'))

    items, kills = {}, {}
    for p in store.values():
        for key, it in p['items'].items():
            out = items.setdefault(key, {'zones': {}, 'mobs': {}, 'cat': it.get('cat'), 'name': it.get('name')})
            for mapID, cells in it['zones'].items():
                z = out['zones'].setdefault(mapID, {})
                for ck, c in cells.items():
                    o = z.get(ck)
                    if not o:
                        z[ck] = dict(c)
                    else:
                        tot = o['n'] + c['n']
                        o['x'] = round((o['x'] * o['n'] + c['x'] * c['n']) / tot, 1)
                        o['y'] = round((o['y'] * o['n'] + c['y'] * c['n']) / tot, 1)
                        o['n'] = tot
            for npcID, m in it['mobs'].items():
                o = out['mobs'].get(npcID)
                if not o: out['mobs'][npcID] = dict(m)
                else:
                    o['n'] += m['n']; o['lvl'] = o['lvl'] or m['lvl']; o['name'] = o['name'] or m['name']
        for npcID, n in p['kills'].items():
            kills[npcID] = kills.get(npcID, 0) + n
    # drop empty items
    items = {k: v for k, v in items.items() if v['zones'] or v['mobs']}
    return items, kills, len(store)

# ---------------------------------------------------------------- writing
def lua_str(s):
    return '"' + str(s).replace('\\', '\\\\').replace('"', '\\"').replace('\n', ' ') + '"'

def lua_key(k):
    return '[%d]' % k if isinstance(k, int) else '[%s]' % lua_str(k)

def write(items, kills, players, out):
    L = ['-- FarmAtlas - Community data',
         '-- Generated by tools/merge_community.py - do not edit by hand.',
         'local _, ns = ...',
         'ns.Community = { players = %d, built = %s, kills = {' % (players, lua_str(time.strftime('%Y-%m-%d'))),]
    for npcID in sorted(kills):
        L.append('  [%d] = %d,' % (npcID, kills[npcID]))
    L.append('}, items = {')
    for key in sorted(items, key=lambda k: (isinstance(k, str), str(k))):
        it = items[key]
        L.append('  %s = { cat = %s,%s zones = {' % (lua_key(key), lua_str(it.get('cat') or 'learned'),
                 (' name = %s,' % lua_str(it['name'])) if it.get('name') else ''))
        for mapID in sorted(it['zones']):
            cells = ', '.join('[%s] = { x = %s, y = %s, n = %d }' % (lua_str(ck), c['x'], c['y'], c['n'])
                              for ck, c in sorted(it['zones'][mapID].items()))
            L.append('    [%d] = { %s },' % (mapID, cells))
        L.append('  }, mobs = {')
        for npcID in sorted(it['mobs']):
            m = it['mobs'][npcID]
            extra = ''
            if m.get('lvl'): extra += ', lvl = %d' % m['lvl']
            if m.get('name'): extra += ', name = %s' % lua_str(m['name'])
            L.append('    [%d] = { n = %d%s },' % (npcID, m['n'], extra))
        L.append('  } },')
    L.append('} }')
    open(out, 'w', encoding='utf-8').write('\n'.join(L) + '\n')

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('files', nargs='+')
    ap.add_argument('-o', '--out', default=os.path.join(os.path.dirname(__file__), '..', 'Data', 'Community.lua'))
    a = ap.parse_args()
    items, kills, players = merge(a.files)
    write(items, kills, players, a.out)
    print('players: %d  items: %d  npcs with kill counts: %d  -> %s' % (players, len(items), len(kills), a.out))
