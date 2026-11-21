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

def load_community(path):
    """the Community.lua of the last release: never lose what it already had"""
    if not path or not os.path.exists(path): return None
    src = open(path, encoding='utf-8', errors='replace').read()
    out = {}
    for name in ('', '.recipes', '.pools', '.trainerPos', '.fishObjects'):
        m = re.search(r'ns\.Community' + re.escape(name) + r'\s*=\s*', src)
        if m:
            rest = src[m.end():]
            nxt = re.search(r'\n(?:--[^\n]*\n)*ns\.Community\.', rest)
            out[name or 'main'] = Parser(tokenize(rest[:nxt.start()] if nxt else rest)).value()
    return out

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
        chars = [str(c).split('-', 1)[-1].split('@')[0] for c in (db.get('chars') or {})]
        own_origin = chars[0] if chars else os.path.basename(os.path.dirname(os.path.dirname(path))) or path
        aliases = set(chars)
        own = {k: v for k, v in (db.get('learned') or {}).items()
               if isinstance(v, dict) and (v.get('own') or (v.get('total') or 0) > 0)}
        take_player(store, own_origin, own, db.get('kills'))
        for sender, s in (db.get('shared') or {}).items():
            if not isinstance(s, dict): continue
            origin = own_origin if str(sender).split('-')[0].split(' ')[0] in aliases else str(sender).split('-')[0]
            take_player(store, origin, s.get('items'), s.get('kills'))

    # recipe sources (trainer / vendor / drop), fishing schools, trainer positions
    recipes, pools, tpos, fobjs = {}, {}, {}, {}
    def add_src(recipe, s):
        if not isinstance(s, dict) or not recipe: return
        typ, npc = s.get('type'), s.get('npc')
        if typ not in ('trainer', 'vendor', 'drop') or not npc: return
        try: m, x, y = int(s.get('mapID')), float(s.get('x')), float(s.get('y'))
        except (TypeError, ValueError): return
        if not (0 <= x <= 100 and 0 <= y <= 100): return
        lst = recipes.setdefault(str(recipe), [])
        for o in lst:
            if o['type'] == typ and o['npc'] == npc: return
        e = {'type': typ, 'npc': str(npc), 'mapID': m, 'x': round(x, 1), 'y': round(y, 1)}
        fac = s.get('faction') or s.get('fac')
        if fac in ('Horde', 'Alliance', 'H', 'A', 'N'): e['faction'] = {'H': 'Horde', 'A': 'Alliance'}.get(fac, fac)
        c = s.get('copper')
        if isinstance(c, (int, float)) and c > 0: e['copper'] = int(c)
        lst.append(e)
    for path in files:
        db = load_saved(path)
        for recipe, lst in (db.get('recipeSources') or {}).items():
            for s in (lst.values() if isinstance(lst, dict) else lst or []): add_src(recipe, s)
        for sender, sp in (db.get('shared') or {}).items():
            if isinstance(sp, dict):
                for recipe, lst in (sp.get('recipes') or {}).items():
                    for s in (lst.values() if isinstance(lst, dict) else lst or []): add_src(recipe, s)
        for objID, pl in (db.get('pools') or {}).items():
            try: objID = int(objID)
            except (TypeError, ValueError): continue
            if not isinstance(pl, dict): continue
            o = pools.setdefault(objID, {'fish': {}, 'zones': {}})
            for fid, n in (pl.get('fish') or {}).items():
                try: o['fish'][int(fid)] = o['fish'].get(int(fid), 0) + int(n)
                except (TypeError, ValueError): pass
            for mapID, cells in (pl.get('zones') or {}).items():
                z = o['zones'].setdefault(int(mapID), {})
                for ck, c in (cells or {}).items():
                    if not isinstance(c, dict): continue
                    try: x, y, n = float(c.get('x')), float(c.get('y')), int(c.get('n') or 1)
                    except (TypeError, ValueError): continue
                    oc = z.get(str(ck))
                    if oc: oc['n'] += n
                    else: z[str(ck)] = {'x': round(x, 1), 'y': round(y, 1), 'n': n}
        for npc, tp in (db.get('trainerPos') or {}).items():
            if isinstance(tp, dict):
                try: tpos[str(npc)] = {'mapID': int(tp['mapID']), 'x': round(float(tp['x']), 1), 'y': round(float(tp['y']), 1)}
                except (KeyError, TypeError, ValueError): pass
        def add_obj(name, ob, own):
            if not isinstance(ob, dict) or not isinstance(name, str) or not (2 <= len(name) <= 40): return
            o = fobjs.setdefault(name, {'items': {}, 'zones': {}})
            for iid, n in (ob.get('items') or {}).items():
                try: iid, n = int(iid), int(n)
                except (TypeError, ValueError): continue
                o['items'][iid] = o['items'].get(iid, 0) + n if own else max(o['items'].get(iid, 0), n)
            for mapID, cells in (ob.get('zones') or {}).items():
                try: z = o['zones'].setdefault(int(mapID), {})
                except (TypeError, ValueError): continue
                for c in (cells or {}).values():
                    if not isinstance(c, dict): continue
                    try: x, y, n = float(c.get('x')), float(c.get('y')), int(c.get('n') or 1)
                    except (TypeError, ValueError): continue
                    ck = '%d:%d' % (round(x), round(y))
                    oc = z.get(ck)
                    if not oc: z[ck] = {'x': round(x, 1), 'y': round(y, 1), 'n': n}
                    elif own: oc['n'] += n
                    else: oc['n'] = max(oc['n'], n)
        for name, ob in (db.get('fishObjects') or {}).items(): add_obj(name, ob, True)
        # what guild / group members sent you (by maximum: their own file may come too)
        for sender, sp in (db.get('shared') or {}).items():
            if not isinstance(sp, dict): continue
            for name, ob in (sp.get('fishObjects') or {}).items(): add_obj(name, ob, False)
            for npc, tp in (sp.get('trainerPos') or {}).items():
                if isinstance(tp, dict) and str(npc) not in tpos:
                    try: tpos[str(npc)] = {'mapID': int(tp['mapID']), 'x': round(float(tp['x']), 1), 'y': round(float(tp['y']), 1)}
                    except (KeyError, TypeError, ValueError): pass
            for objID, pl in (sp.get('pools') or {}).items():
                try: objID = int(objID)
                except (TypeError, ValueError): continue
                if not isinstance(pl, dict): continue
                o = pools.setdefault(objID, {'fish': {}, 'zones': {}})
                for fid in (pl.get('fish') or {}):
                    try: o['fish'].setdefault(int(fid), 1)
                    except (TypeError, ValueError): pass
                for mapID, cells in (pl.get('zones') or {}).items():
                    z = o['zones'].setdefault(int(mapID), {})
                    for c in (cells or {}).values():
                        if not isinstance(c, dict): continue
                        try: x, y, n = float(c.get('x')), float(c.get('y')), int(c.get('n') or 1)
                        except (TypeError, ValueError): continue
                        ck = '%d:%d' % (round(x), round(y))
                        oc = z.get(ck)
                        if not oc or n > oc['n']: z[ck] = {'x': round(x, 1), 'y': round(y, 1), 'n': n}
    merge.extra = (recipes, pools, tpos, fobjs)

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
    # keep everything the last release already had (max per cell / count, union of sources)
    base = load_community(getattr(merge, 'base', None))
    players = len(store)
    if base:
        bm = base.get('main') or {}
        players = max(players, int(bm.get('players') or 0))
        for npcID, n in (bm.get('kills') or {}).items():
            npcID = key_norm(npcID)
            kills[npcID] = max(kills.get(npcID, 0), int(n))
        for key, it in (bm.get('items') or {}).items():
            key = key_norm(key)
            out = items.setdefault(key, {'zones': {}, 'mobs': {}, 'cat': it.get('cat'), 'name': it.get('name')})
            for mapID, cells in (it.get('zones') or {}).items():
                z = out['zones'].setdefault(key_norm(mapID), {})
                for ck, c in cells.items():
                    o = z.get(ck)
                    if not o or c['n'] > o['n']: z[ck] = {'x': c['x'], 'y': c['y'], 'n': int(c['n'])}
            for npcID, m in (it.get('mobs') or {}).items():
                npcID = key_norm(npcID)
                o = out['mobs'].get(npcID)
                if not o or int(m['n']) > o['n']:
                    out['mobs'][npcID] = {'n': int(m['n']), 'lvl': m.get('lvl'), 'name': m.get('name')}
        recipes, pools, tpos, fobjs = merge.extra
        for r, lst in (base.get('.recipes') or {}).items():
            for e in lst.values() if isinstance(lst, dict) else lst:
                have = recipes.setdefault(r, [])
                if not any(o['type'] == e['type'] and o['npc'] == e['npc'] for o in have):
                    have.append({k: key_norm(v) for k, v in e.items()})
        for objID, pl in (base.get('.pools') or {}).items():
            objID = key_norm(objID)
            o = pools.setdefault(objID, {'fish': {}, 'zones': {}})
            for fid, n in (pl.get('fish') or {}).items():
                fid = key_norm(fid); o['fish'][fid] = max(o['fish'].get(fid, 0), int(n))
            for mapID, cells in (pl.get('zones') or {}).items():
                z = o['zones'].setdefault(key_norm(mapID), {})
                for ck, c in cells.items():
                    oc = z.get(ck)
                    if not oc or c['n'] > oc['n']: z[ck] = {'x': c['x'], 'y': c['y'], 'n': int(c['n'])}
        for npc, tp in (base.get('.trainerPos') or {}).items():
            tpos.setdefault(npc, {'mapID': int(tp['mapID']), 'x': tp['x'], 'y': tp['y']})
        for name, ob in (base.get('.fishObjects') or {}).items():
            o = fobjs.setdefault(name, {'items': {}, 'zones': {}})
            for iid, n in (ob.get('items') or {}).items():
                iid = key_norm(iid); o['items'][iid] = max(o['items'].get(iid, 0), int(n))
            for mapID, cells in (ob.get('zones') or {}).items():
                z = o['zones'].setdefault(key_norm(mapID), {})
                for ck, c in cells.items():
                    oc = z.get(ck)
                    if not oc or c['n'] > oc['n']: z[ck] = {'x': c['x'], 'y': c['y'], 'n': int(c['n'])}
    # drop empty items
    items = {k: v for k, v in items.items() if v['zones'] or v['mobs']}
    return items, kills, players

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
    recipes, pools, tpos, fobjs = getattr(merge, 'extra', ({}, {}, {}, {}))
    L.append('-- where recipes are taught / sold / dropped, as players saw it')
    L.append('ns.Community.recipes = {')
    for r in sorted(recipes):
        ents = []
        for e in recipes[r]:
            f = 'type = %s, npc = %s, mapID = %d, x = %s, y = %s' % (lua_str(e['type']), lua_str(e['npc']), e['mapID'], e['x'], e['y'])
            if e.get('faction'): f += ', faction = %s' % lua_str(e['faction'])
            if e.get('copper'): f += ', copper = %d' % e['copper']
            ents.append('{ %s }' % f)
        L.append('  [%s] = { %s },' % (lua_str(r), ', '.join(ents)))
    L.append('}')
    L.append('-- fishing schools players fished from')
    L.append('ns.Community.pools = {')
    for objID in sorted(pools):
        pl = pools[objID]
        fish = ', '.join('[%d] = %d' % (k, v) for k, v in sorted(pl['fish'].items()))
        zs = []
        for mapID in sorted(pl['zones']):
            cells = ', '.join('[%s] = { x = %s, y = %s, n = %d }' % (lua_str(ck), c['x'], c['y'], c['n']) for ck, c in sorted(pl['zones'][mapID].items()))
            zs.append('[%d] = { %s }' % (mapID, cells))
        L.append('  [%d] = { fish = { %s }, zones = { %s } },' % (objID, fish, ', '.join(zs)))
    L.append('}')
    L.append('-- trainer positions measured in game')
    L.append('ns.Community.trainerPos = {')
    for npc in sorted(tpos):
        tp = tpos[npc]
        L.append('  [%s] = { mapID = %d, x = %s, y = %s },' % (lua_str(npc), tp['mapID'], tp['x'], tp['y']))
    L.append('}')
    L.append('-- fishable wreckage / debris players fished from')
    L.append('ns.Community.fishObjects = {')
    for name in sorted(fobjs):
        ob = fobjs[name]
        its = ', '.join('[%d] = %d' % (k, v) for k, v in sorted(ob['items'].items()))
        zs = []
        for mapID in sorted(ob['zones']):
            cells = ', '.join('[%s] = { x = %s, y = %s, n = %d }' % (lua_str(ck), c['x'], c['y'], c['n']) for ck, c in sorted(ob['zones'][mapID].items()))
            zs.append('[%d] = { %s }' % (mapID, cells))
        L.append('  [%s] = { items = { %s }, zones = { %s } },' % (lua_str(name), its, ', '.join(zs)))
    L.append('}')
    open(out, 'w', encoding='utf-8').write('\n'.join(L) + '\n')

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('files', nargs='+')
    ap.add_argument('-o', '--out', default=os.path.join(os.path.dirname(__file__), '..', 'Data', 'Community.lua'))
    ap.add_argument('--base', help='Community.lua of the last release (default: the output file)')
    a = ap.parse_args()
    merge.base = a.base or a.out
    items, kills, players = merge(a.files)
    write(items, kills, players, a.out)
    r, pl, tp, fo = getattr(merge, 'extra', ({}, {}, {}, {}))
    print('players: %d  items: %d  npcs with kill counts: %d  recipes: %d  schools: %d  trainers: %d  fishable objects: %d  -> %s' % (players, len(items), len(kills), len(r), len(pl), len(tp), len(fo), a.out))
