"""Rebuild editable Godot scenes from saved Figma exports (no API credentials)."""
import concurrent.futures, hashlib, json, re, urllib.request, sys
from pathlib import Path
from html.parser import HTMLParser
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets' / 'figma'
ASSETS.mkdir(parents=True, exist_ok=True)

class JSX(HTMLParser):
    def __init__(self, code):
        super().__init__(); self.stack=[]; self.images={}; self.texts={}; self.styles={}
        self.feed(re.sub(r'src=\{(\w+)\}', r'src="\1"', code))
    def handle_starttag(self, tag, attrs):
        a=dict(attrs)
        if tag=='img':
            node=next((s for s in reversed(self.stack) if s),None)
            if node: self.images.setdefault(node,a.get('src'))
        else:
            node=a.get('data-node-id'); self.stack.append(node)
            if node: self.styles[node]=a.get('classname','')
    def handle_startendtag(self, tag, attrs):
        if tag=='img': self.handle_starttag(tag,attrs)
    def handle_endtag(self,tag):
        if self.stack: self.stack.pop()
    def handle_data(self,data):
        if self.stack and self.stack[-1] and data.strip(): self.texts[self.stack[-1]]=data.strip()

def q(s): return json.dumps(s,ensure_ascii=False)
frames=[('planning','56:614','design-context.txt'),('day','56:1146','day-context.txt'),('night','56:1641','night-context.txt')]
xml=ET.parse(ROOT/'source/metadata.xml').getroot()
downloads={}; scenes=[]
for name,fid,source in frames:
    code=(ROOT/'source'/source).read_text(encoding='utf-8'); p=JSX(code[code.index('export default'):code.index('\nSUPER CRITICAL') if '\nSUPER CRITICAL' in code else len(code)])
    urls=dict(re.findall(r'const (\w+) = "(https:[^"]+)";',code))
    bounds={b[0]:b[1:] for b in json.loads((ROOT/f'source/bounds-{fid.replace(":","-")}.json').read_text())}
    frame=next(f for f in xml if f.attrib['id']==fid)
    layers=[]
    for i,node in enumerate(frame):
        a=node.attrib; nid=a['id']; b=bounds.get(nid,[float(a[k]) for k in ['x','y','width','height']])
        if node.tag=='text':
            style=p.styles.get(nid,''); size=re.search(r'text-\[(\d+)px\]',style); color=re.search(r'text-\[(#[a-fA-F0-9]+)\]',style)
            layers.append(dict(id=nid,kind='text',text=a['name'],rect=[float(a[k]) for k in ['x','y','width','height']],size=int(size[1]) if size else 16,color=color[1] if color else '#304a42',bold='font-bold' in style))
        else:
            var=p.images.get(nid)
            if i==0: var=p.images.get(fid,var)
            if not var:
                raise RuntimeError(f'Missing image mapping {name} {nid}')
            url=urls[var]; filename=hashlib.sha256(url.encode()).hexdigest()[:16]+'.svg'; downloads[filename]=url
            layers.append(dict(id=nid,kind='image',asset=filename,rect=b))
    scenes.append((name,layers))

def fetch(item):
    fn,url=item; dest=ASSETS/fn
    if not dest.exists():
        with urllib.request.urlopen(url,timeout=60) as r: dest.write_bytes(r.read())
    if b'<svg' not in dest.read_bytes(): raise RuntimeError(fn)
    return fn
(ROOT/'source/asset-manifest.json').write_text(json.dumps(downloads,indent=2),encoding='utf-8')
if '--manifest-only' in sys.argv: sys.exit(0)
for filename in downloads:
    if not (ASSETS/filename).exists() or b'<svg' not in (ASSETS/filename).read_bytes():
        raise RuntimeError('Download required: '+filename)

for name,layers in scenes:
    assets=list(dict.fromkeys(n['asset'] for n in layers if n['kind']=='image'))
    lines=['[gd_scene load_steps=%d format=3]'%(len(assets)+3),'','[ext_resource type="FontFile" path="res://assets/fonts/regular.ttc" id="font"]','[ext_resource type="FontFile" path="res://assets/fonts/bold.ttc" id="bold"]']
    for i,a in enumerate(assets): lines.append(f'[ext_resource type="Texture2D" path="res://assets/figma/{a}" id="a{i}"]')
    lines+=['',f'[node name="{name.title()}" type="Node2D"]']
    for layer in layers:
        nid=layer['id'].replace(':','_'); x,y,w,h=layer['rect']; t='Label' if layer['kind']=='text' else 'Sprite2D'
        label='Text' if t=='Label' else 'Art'
        lines+=['',f'[node name="{label}_{nid}" type="{t}" parent="."]']
        if t=='Sprite2D':
            asset=layer['asset']; svg=ET.parse(ASSETS/asset).getroot(); vb=list(map(float,svg.attrib['viewBox'].split())); sw,sh=vb[2:]
            lines += [f'position = Vector2({x}, {y})','centered = false',f'texture = ExtResource("a{assets.index(asset)}")',f'scale = Vector2({w/sw}, {h/sh})']
        else:
            c=layer['color'].lstrip('#'); rgb=[int(c[k:k+2],16)/255 for k in [0,2,4]]
            lines += [f'offset_left = {x}',f'offset_top = {y-2}',f'offset_right = {x+w+30}',f'offset_bottom = {y+h+5}','mouse_filter = 2',f'theme_override_colors/font_color = Color({rgb[0]}, {rgb[1]}, {rgb[2]}, 1)',f'theme_override_fonts/font = ExtResource("{"bold" if layer["bold"] else "font"}")',f'theme_override_font_sizes/font_size = {layer["size"]}',f'text = {q(layer["text"])}']
    (ROOT/'scenes').mkdir(exist_ok=True)
    (ROOT/f'scenes/{name}.tscn').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    (ROOT/f'source/{name}-layers.json').write_text(json.dumps(layers,ensure_ascii=False,indent=2),encoding='utf-8')
(ROOT/'source/asset-manifest.json').write_text(json.dumps(downloads,indent=2),encoding='utf-8')
print(f'Imported {len(downloads)} exact SVG assets; layers: '+str([(n,len(l)) for n,l in scenes]))
plan=scenes[0][1]
fence_rects={tuple(n['rect']) for n in plan if 735<=int(n['id'].split(':')[1])<=790 or 957<=int(n['id'].split(':')[1])<=1047}
selected_rects={tuple(n['rect']) for n in plan if 649<=int(n['id'].split(':')[1])<=667}
config=[]
for (name,layers),(_,fid,_) in zip(scenes,frames):
    frame=next(f for f in xml if f.attrib['id']==fid)
    groups={n.attrib['id'] for n in frame if n.tag=='frame' and n.attrib.get('name')=='Group'}
    config.append({'fences':['Art_'+n['id'].replace(':','_') for n in layers if tuple(n['rect']) in fence_rects], 'selected':['Art_'+n['id'].replace(':','_') for n in layers if tuple(n['rect']) in selected_rects], 'actors':[['Art_'+n['id'].replace(':','_'), n['rect'][1]+n['rect'][3]-10 if n['rect'][3]>40 else 3] for n in layers if n['id'] in groups]})
(ROOT/'source/runtime-layers.json').write_text(json.dumps(config),encoding='utf-8')
