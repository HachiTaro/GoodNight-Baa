"""Verify documentation fixtures only; this does not test a Godot implementation."""
import json
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIRS = [(0, -1), (1, 0), (0, 1), (-1, 0)]


def rect(x1, x2, y1, y2):
    return {(x, y) for y in range(y1, y2 + 1) for x in range(x1, x2 + 1)}


def make_level(n, title, w, h, grass, water, rocks, sheep, budget, stars, solutions):
    rows = []
    for y in range(1, h + 1):
        rows.append(''.join('R' if (x, y) in rocks else 'W' if (x, y) in water
                            else 'g' if (x, y) in grass else '.' for x in range(1, w + 1)))
    return dict(schema_version=1, id=f'level_{n:02}', title=title,
                status='source_example' if n <= 2 else 'candidate', revision=1,
                width=w, height=h, terrain_rows=rows,
                sheep=[dict(id=f's{i+1:02}', x=x, y=y) for i, (x, y) in enumerate(sheep)],
                wolf_entries=[dict(id='wolf_01', x=0 if n != 2 else w+1, y=3)],
                budget=budget, initial_inventory=dict(grass=0, water=0),
                star_thresholds=dict(three=stars[0], two=stars[1]),
                pk_config=dict(enabled=n >= 6, target_seconds={6: 30, 7: 25, 8: 22}.get(n),
                               correct_to_win=5), objective_key=f'level.{n:02}.request',
                tutorial_id=f'tutorial_{n:02}' if n <= 2 else '', season='spring',
                reference_solutions=solutions)


def sol(name, cells, grass=0, buckets=0, discount=False):
    return dict(id=name, selected_cells=[list(p) for p in sorted(cells, key=lambda p:(p[1],p[0]))],
                buy_grass=grass, buy_water_buckets=buckets, discount=discount)


def fixtures():
    out=[]
    out.append(make_level(1,'给两只羊一个家',6,5,rect(3,4,2,3),set(),set(),[(3,3),(4,3)],16,(12,14),[
        sol('reference',rect(3,4,2,3),buckets=1)]))
    out.append(make_level(2,'借一段水岸',8,6,rect(2,5,3,4),{(6,3)},set(),[(3,3),(4,3),(3,4),(4,4)],24,(11,16),[
        sol('vertical',rect(3,4,2,5),grass=4,buckets=1),sol('horizontal',rect(2,5,3,4))]))
    out.append(make_level(3,'草在哪里',9,6,{(3,4),(4,4)}|rect(6,7,3,4),set(),set(),[(3,4),(4,4)],20,(16,18),[
        sol('compact_buy',rect(3,4,3,4),grass=2,buckets=1),sol('expand_grass',rect(3,7,3,4),buckets=1)]))
    out.append(make_level(4,'山的两边',9,6,rect(2,3,3,4)|rect(7,8,3,4),set(),rect(5,5,2,5),
        [(2,3),(3,3),(7,3),(8,3)],24,(20,22),[sol('separate',rect(2,3,3,4)|rect(7,8,3,4),buckets=1)]))
    a=rect(2,3,3,4); b=rect(9,12,3,4); corridor=rect(4,8,4,4)
    for n in (5,):
        out.append(make_level(n,'连成一家',13,6,b,{(1,3)},rect(4,8,3,3),[(2,3),(3,3),(10,3),(11,3)],32,(27,29),[
            sol('separate',a|b,grass=4,buckets=1),sol('connected',a|b|corridor)]))
    out.append(make_level(6,'商人的挑战',7,5,{(3,3),(4,3)},set(),set(),[(3,3),(4,3)],18,(12,14),[
        sol('regular',rect(3,4,2,3),grass=2,buckets=1),sol('discount',rect(3,4,2,3),grass=2,buckets=1,discount=True)]))
    out.append(make_level(7,'今天有折扣',13,6,b,{(1,3)},rect(4,8,3,3),[(2,3),(3,3),(10,3),(11,3)],32,(25,27),[
        sol('separate_regular',a|b,grass=4,buckets=1),sol('connected_regular',a|b|corridor),
        sol('separate_discount',a|b,grass=4,buckets=1,discount=True),sol('connected_discount',a|b|corridor,discount=True)]))
    # Two additional sheep on the fertile side require four more grass in either layout.
    out.append(make_level(8,'晚安大草原',13,6,b,{(1,3)},rect(4,8,3,3),
        [(2,3),(3,3),(9,3),(10,3),(11,3),(12,3)],40,(31,35),[
            sol('separate_regular',a|b,grass=4,buckets=1),
            sol('connected_regular',a|b|corridor,grass=4),
            sol('separate_discount',a|b,grass=4,buckets=1,discount=True),
            sol('connected_discount',a|b|corridor,grass=4,discount=True)]))
    return out


def analyze(level, solution):
    w,h=level['width'],level['height']; rows=level['terrain_rows']
    def terrain(p):
        x,y=p
        return rows[y-1][x-1] if 1<=x<=w and 1<=y<=h else '.'
    cells=set(map(tuple,solution['selected_cells']))
    assert len(cells)==len(solution['selected_cells'])
    assert all(1<=x<=w and 1<=y<=h and terrain((x,y)) in '.g' for x,y in cells)
    sheep={(s['x'],s['y']):s['id'] for s in level['sheep']}
    assert set(sheep)<=cells
    components=[]; left=set(cells); fence=set()
    for seed in sorted(cells,key=lambda p:(p[1],p[0])):
        if seed not in left: continue
        part={seed}; left.remove(seed); todo=[seed]
        while todo:
            x,y=todo.pop()
            for dx,dy in DIRS:
                q=(x+dx,y+dy)
                if q in left: left.remove(q);part.add(q);todo.append(q)
        pcount=water=0
        for x,y in part:
            for dx,dy in DIRS:
                q=(x+dx,y+dy)
                if q in cells: continue
                pcount+=1
                if terrain(q)=='W':water+=1
                else:fence.add(tuple(sorted(((x,y),q))))
        n=len(part&set(sheep)); natural=sum(terrain(p)=='g' for p in part)
        assert len(part)>=2*n
        components.append(dict(area=len(part),perimeter=pcount,water_edges=water,fence=pcount-water,
                               sheep=n,natural_grass=natural,grass_gap=max(0,2*n-natural),water_gap=0 if water else n))
    grass_gap=sum(c['grass_gap'] for c in components);water_gap=sum(c['water_gap'] for c in components)
    assert solution['buy_grass']>=grass_gap
    assert solution['buy_water_buckets']*4>=water_gap
    # Flood fill wolves independently from selected-component logic.
    for entry in level['wolf_entries']:
        seed=(entry['x'],entry['y']); visited={seed};q=deque([seed])
        while q:
            p=q.popleft()
            for dx,dy in DIRS:
                v=(p[0]+dx,p[1]+dy)
                if v in visited or not (0<=v[0]<=w+1 and 0<=v[1]<=h+1):continue
                if terrain(v) in 'WRB' or tuple(sorted((p,v))) in fence:continue
                visited.add(v);q.append(v)
        assert not (visited&set(sheep)), 'wolf reached sheep'
    price_grass,price_water=(1,2) if solution['discount'] else (2,4)
    fc=len(fence); supplies=solution['buy_grass']*price_grass+solution['buy_water_buckets']*price_water
    total=fc+supplies; assert total<=level['budget']
    stars=3 if total<=level['star_thresholds']['three'] else 2 if total<=level['star_thresholds']['two'] else 1
    return dict(components=components,area=sum(c['area'] for c in components),
                perimeter=sum(c['perimeter'] for c in components),water_edges=sum(c['water_edges'] for c in components),
                fence=fc,grass_gap=grass_gap,water_gap=water_gap,supply_cost=supplies,total=total,
                balance=level['budget']-total,stars=stars,water_remaining=solution['buy_water_buckets']*4-water_gap)


def main():
    levels=fixtures(); outputs=[]
    for level in levels:
        assert len(level['terrain_rows'])==level['height']
        assert all(len(row)==level['width'] for row in level['terrain_rows'])
        for solution in level['reference_solutions']:
            result=analyze(level,solution); solution['expected']=result
            outputs.append((level['id'],solution['id'],result))
    by_key={(l,s):r for l,s,r in outputs}
    assert by_key['level_01','reference']['total']==12
    assert by_key['level_02','vertical']['total']==24
    assert by_key['level_02','horizontal']['total']==11
    assert by_key['level_05','separate']['total']==31
    assert by_key['level_05','connected']['total']==27
    assert by_key['level_07','separate_discount']['total']==25
    (ROOT/'data').mkdir(exist_ok=True)
    (ROOT/'data/levels_document_examples.json').write_text(json.dumps(dict(schema_version=1,
        note='Levels 1-2 follow V3 examples; levels 3-8 are unapproved playable candidates.',levels=levels),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    lines=['# 文档数值核验记录','', '核验日期：2026-09-17。此记录验证文档中的候选数据，不代表 Godot 游戏已开发或测试。','',
           '方法：逐格枚举边界、四邻域分量、独立狼行动图 BFS、逐牧场容量/资源/整数费用检查。','',
           '| 关卡 | 方案 | A | P | W | F | 补给费 | 总支出 | 余额 | 星级 |',
           '|---|---|---:|---:|---:|---:|---:|---:|---:|---:|']
    for level,solution,r in outputs:
        lines.append(f"| {level} | {solution} | {r['area']} | {r['perimeter']} | {r['water_edges']} | {r['fence']} | {r['supply_cost']} | {r['total']} | {r['balance']} | {r['stars']} |")
    lines+=['','结果：全部 '+str(len(outputs))+' 条参考路线通过上述断言；每关至少一条原价解；第5关连接节省4金币，第7关折扣后分开比连接节省2金币。','',
            '核验范围：地形合法、羊被圈入、每牧场容量与供给、外圈狼不可达、支出不超预算、星级阈值、前两关原稿数字。', '',
            '未验证：全局最优解、真实游玩难度、教学时长、后六关正式策划批准、Godot实现、界面交互、素材替换、存档事务、Web导出与目标设备性能。后续必须执行05中的游戏验收。','',
            '可复现工具：tools/verify_document_examples.py（Python 3 标准库）。输入候选图与方案在该脚本中明确定义；它生成随附 JSON 与此记录。修改 JSON 后请同步修改工具中的配置再重新核验，避免生成器覆盖未同步编辑。','']
    (ROOT/'核验记录.md').write_text('\n'.join(lines),encoding='utf-8')
    print('\n'.join(lines))


if __name__=='__main__':main()
