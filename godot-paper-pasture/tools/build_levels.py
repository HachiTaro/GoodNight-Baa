"""Author the eight V3 levels. Coordinates in solution data are one-based."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def rect(x,y,w,h): return [[a,b] for b in range(y,y+h) for a in range(x,x+w)]
def level(i,title,rows,budget,stars,hint,solution,grass=0,water=0,pk=0):
    return dict(id=i,title=title,grid=rows,budget=budget,stars=stars,hint=hint,
        wolf_entries=[[0,3]] if i%2 else [[len(rows[0])+1,3]],pk_seconds=pk,
        reference=dict(cells=solution,grass=grass,water_buckets=water),
        theme=['spring','spring','summer','summer','autumn','spring','autumn','nightfall'][i-1])
levels=[]
levels.append(level(1,'给两只羊一个家',['......','..gg..','..SS..','......','......'],16,[12,14],
 '围住两只羊和它们身后的两格牧草，再去小镇买一桶水。',rect(3,2,2,2),water=1))
levels.append(level(2,'借一段水岸',['........','........','.gSSgW..','.gSSg...','........','........'],24,[11,16],
 '水岸既能供水，也能省围栏。试着把两排牧草连成一个家。',rect(2,3,4,2)))
levels.append(level(3,'草在哪里',['........','..g..g..','..ss....','..gg.g..','........','........'],24,[16,20],
 '羊每天各吃两份草。多围一点找草，还是向商人买草？',rect(3,3,2,2),grass=2,water=1))
levels.append(level(4,'山的两边',['.........','.gS.#.Sg.','.gS.#.SgW','....#....','.........','.........'],30,[20,24],
 '山石不能圈入。两个牧场要分别够住、够吃、够喝。',rect(2,2,2,2)+rect(7,2,2,2),water=1))
# A has water but no grass; B has eight grass units but no water.
# Five corridor cells add 8 fences. Separate normal=30, joined=26,
# separate discounted=24. The reversal is verified against the actual grid.
bridge_rows=['...........','........gg.','Ws..##..Sg.','W.s.....gS.','........gg.','...........','...........']
separate=rect(2,3,2,2)+rect(9,2,2,4)
joined=separate+rect(4,4,5,1)
levels.append(level(5,'连成一家',bridge_rows,36,[26,30],
 '左边有水，右边有草。沿山下连一条草地，把两个家连起来。',joined))
levels.append(level(6,'商人的挑战',['.......','.......','..ss...','..gg...','.......','.......'],22,[12,17],
 '商人愿意比一比口算。赢得五折可省钱，原价也能通关。',rect(3,3,2,2),grass=2,water=1,pk=30))
levels.append(level(7,'今天有折扣',bridge_rows,34,[24,28],
 '先算总账：连起来省补给，五折后分开购买也许更便宜。',joined,pk=25))
levels.append(level(8,'晚安大草原',['............','.gS...Sg....','WgS...Sg....','W......#....','.......#.gS.','.........gS.','............','............'],42,[30,35],
 '照顾好三个牧场。检查每家的草、水和空间，再让夜晚到来。',rect(2,2,2,2)+rect(7,2,2,2)+rect(10,5,2,2),water=1,pk=22))
for i in [4,6]:
    levels[i]['alternatives']=[dict(name='分开补给',cells=separate,grass=4,water_buckets=1,normal_cost=30,discount_cost=24),dict(name='连通共享',cells=joined,grass=0,water_buckets=0,normal_cost=26,discount_cost=26)]
(ROOT/'data').mkdir(exist_ok=True)
(ROOT/'data/levels.json').write_text(json.dumps(dict(version=1,coordinates='one-based x,y; grid strings top to bottom',legend={'.':'land','g':'grass','S':'sheep on grass','s':'sheep on land','W':'water','#':'rock','H':'building'},levels=levels),ensure_ascii=False,indent=2),encoding='utf-8')
print('Wrote eight JSON levels')
