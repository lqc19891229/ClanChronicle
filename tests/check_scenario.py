from pathlib import Path
import json
s = json.loads((Path(__file__).resolve().parents[1] / 'data/scenario.json').read_text(encoding='utf-8'))
assert s['schema_version'] == 2
clan = next(c for c in s['clans'] if c['id'] == s['player_clan_id'])
regions = {r['id']: r for r in s['regions']}
polities = {r['id'] for r in s['polities']}
settlements = {r['id']: r for r in s['settlements']}
for r in regions.values():
    assert r['parent_id'] == -1 or r['parent_id'] in regions
    assert r['legal_polity_id'] in polities
    assert r['controlling_polity_id'] in polities
for r in settlements.values():
    assert r['region_id'] in regions
assert clan['home_settlement_id'] in settlements
for b in s['branches']:
    assert b['clan_id'] == clan['id']
for h in s['households']:
    assert h['settlement_id'] in settlements
for c in s['characters']:
    assert c['clan_id'] == clan['id'] and c['settlement_id'] in settlements
p = {x['id']: x for x in s['characters']}
h = {x['id']: x for x in s['households']}
b = {x['id']: x for x in s['branches']}
a = {x['id']: x for x in s['ancestors']}
assert len(p) == 24 == len(s['characters'])
assert len(h) == 6 and len(b) == 3
assert not p.keys() & a.keys()
assert clan['leader_id'] in p
for x in p.values():
    assert x['branch_id'] in b and x['household_id'] in h
    assert h[x['household_id']]['branch_id'] == x['branch_id']
    assert len(x['skills']) == 6 and all(0 <= n <= 100 for n in x['skills'])
    for key in ('father_id', 'mother_id', 'spouse_id'):
        assert x[key] == -1 or x[key] in p or x[key] in a
        assert x[key] != x['id']
    if x['spouse_id'] != -1:
        assert p[x['spouse_id']]['spouse_id'] == x['id']
    for key in ('father_id', 'mother_id'):
        if x[key] in p:
            assert p[x[key]]['birth_day'] < x['birth_day']
for x in h.values():
    assert p[x['head_id']]['household_id'] == x['id']
for x in b.values():
    assert p[x['head_id']]['branch_id'] == x['id']
assert sum(x['land'] for x in h.values()) == 240
assert clan['land'] == 80
assert clan['cash'] == 200 and clan['grain'] == 100
print('PASS: scenario data, references, relationships, ownership totals')
