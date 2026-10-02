"""Contact sheet of a cinematic, as the camera sees it (offline preview, not the game).

    luau tests/Storyboard.luau -a KAI Awaken DRAGON 0 6 > story.txt
    python3 tools/storyboard.py story.txt story.png

Needs Python 3 and Pillow. Bodies are the KAI block rig posed by the real animator; effects
are drawn as simple shapes (rings, sparks, arcs, lightning); grading and letterbox as in game.
"""
import os
import sys, math
from PIL import Image, ImageDraw, ImageFont

W = int(os.environ.get('STORY_W', '400'))
H = W * 9 // 16
def sub(a,b): return (a[0]-b[0],a[1]-b[1],a[2]-b[2])
def dot(a,b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
def cross(a,b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def norm(a):
    l = math.sqrt(dot(a,a)) or 1
    return (a[0]/l,a[1]/l,a[2]/l)
def hexc(h):
    h = h.strip('#')
    try: return tuple(int(h[i:i+2],16) for i in (0,2,4))
    except: return (255,255,255)

def parse(path):
    frames = []
    for line in open(path):
        f = line.split()
        if not f: continue
        if f[0] == 'FRAME':
            frames.append({'tick': int(f[1]), 'shot': f[2], 'fov': float(f[3]), 'roll': float(f[4]), 'grade': f[5],
                           'speed': f[6] == '1', 'title': ' '.join(f[7:]), 'parts': [], 'fx': []})
        elif f[0] == 'CAM' and frames:
            n = list(map(float, f[1:7])); frames[-1]['cam'] = (n[0:3], n[3:6])
        elif f[0] == 'PART' and frames:
            nums = list(map(float, f[3:18]))
            # optional 19th field: the part's own colour (hex), else the slot palette
            frames[-1]['parts'].append((int(f[1]), f[2], nums[:12], nums[12:15], False, hexc(f[18]) if len(f) > 18 else None))
        elif f[0] == 'FX' and frames:
            frames[-1]['fx'].append({'kind': f[1], 'age': int(f[2]), 'pos': tuple(map(float, f[3:6])),
                'from': tuple(map(float, f[6:9])), 'to': tuple(map(float, f[9:12])), 'radius': float(f[12]),
                'color': hexc(f[13]), 'tilt': float(f[14]), 'scale': float(f[15]),
                'life': float(f[16]) if len(f) > 16 else 0, 'spin': float(f[17]) if len(f) > 17 else 0,
                'phase': float(f[18]) if len(f) > 18 else 0})
    return frames

PALETTE = {
    1: {'Head': (227,169,138), 'Torso': (200,30,40), 'Arm': (227,169,138), 'Hand': (240,240,240), 'Leg': (30,30,38), 'Foot': (240,240,240)},
    2: {'Head': (200,170,150), 'Torso': (90,110,160), 'Arm': (200,170,150), 'Hand': (210,210,220), 'Leg': (50,55,75), 'Foot': (180,180,190)},
}
def partColor(slot, name):
    p = PALETTE[slot]
    if 'Head' in name: return p['Head']
    if 'Torso' in name: return p['Torso']
    if 'Hand' in name: return p['Hand']
    if 'Foot' in name: return p['Foot']
    if 'Arm' in name: return p['Arm']
    return p['Leg']

def render_frame(fr, label):
    img = Image.new('RGB', (W, H))
    d = ImageDraw.Draw(img, 'RGBA')
    # sunset sky
    for y in range(H):
        t = y / H
        d.line([(0,y),(W,y)], fill=(int(70+120*t), int(40+50*t), int(70+20*t)))
    cam, tgt = fr['cam']
    fwd = norm(sub(tgt, cam))
    right = norm(cross(fwd, (0,1,0)))
    up = cross(right, fwd)
    r = fr['roll']
    right, up = (tuple(right[i]*math.cos(r) + up[i]*math.sin(r) for i in range(3)),
                 tuple(up[i]*math.cos(r) - right[i]*math.sin(r) for i in range(3)))
    f = (H/2) / math.tan(math.radians(fr['fov'])/2)
    def proj(p):
        dd = sub(p, cam)
        z = dot(dd, fwd)
        if z < 0.05: return None
        return (W/2 + dot(dd, right)/z*f, H/2 - dot(dd, up)/z*f, z)
    # floor: horizon fill + grid
    for gx in range(-40, 41, 2):
        a, b = proj((gx, 0, -12)), proj((gx, 0, 14))
        if a and b: d.line([a[:2], b[:2]], fill=(110,80,70,120))
    for gz in range(-12, 15, 2):
        pts = [proj((x, 0, gz)) for x in range(-40, 41, 4)]
        pts = [p[:2] for p in pts if p]
        if len(pts) > 1: d.line(pts, fill=(110,80,70,120))
    # floor edge of the fighting deck
    faces = []
    for slot, name, t, size, ghost, own in fr['parts']:
        px, py, pz = t[0], t[1], t[2]
        R = [[t[3],t[4],t[5]],[t[6],t[7],t[8]],[t[9],t[10],t[11]]]
        hx, hy, hz = size[0]/2, size[1]/2, size[2]/2
        corners = []
        for sx in (-1,1):
            for sy in (-1,1):
                for sz in (-1,1):
                    lx, ly, lz = sx*hx, sy*hy, sz*hz
                    corners.append((px+R[0][0]*lx+R[0][1]*ly+R[0][2]*lz, py+R[1][0]*lx+R[1][1]*ly+R[1][2]*lz,
                                    pz+R[2][0]*lx+R[2][1]*ly+R[2][2]*lz))
        idx = lambda sx,sy,sz: ((sx>0)*4+(sy>0)*2+(sz>0))
        quads = [[idx(-1,-1,-1),idx(-1,1,-1),idx(-1,1,1),idx(-1,-1,1)],[idx(1,-1,-1),idx(1,1,-1),idx(1,1,1),idx(1,-1,1)],
                 [idx(-1,-1,-1),idx(1,-1,-1),idx(1,-1,1),idx(-1,-1,1)],[idx(-1,1,-1),idx(1,1,-1),idx(1,1,1),idx(-1,1,1)],
                 [idx(-1,-1,-1),idx(1,-1,-1),idx(1,1,-1),idx(-1,1,-1)],[idx(-1,-1,1),idx(1,-1,1),idx(1,1,1),idx(-1,1,1)]]
        base = own or partColor(slot, name)
        for q in quads:
            pts3 = [corners[k] for k in q]
            pp = [proj(p) for p in pts3]
            if any(p is None for p in pp): continue
            c = tuple(sum(p[i] for p in pts3)/4 for i in range(3))
            nrm = norm(cross(sub(pts3[1],pts3[0]), sub(pts3[2],pts3[0])))
            ctr = (px,py,pz)
            if dot(nrm, sub(c, ctr)) < 0: nrm = tuple(-x for x in nrm)
            if dot(nrm, sub(c, cam)) >= 0: continue
            light = max(0.35, dot(nrm, norm((0.4,0.8,0.5))))
            col = tuple(int(base[i]*light) for i in range(3))
            depth = dot(sub(c, cam), fwd)
            faces.append((depth, [p[:2] for p in pp], col, ghost))
    # stone pillars (HIBECARES) are solid: sorted with the bodies, on the far half of their ring
    for fx in fr['fx']:
        if fx['kind'] != 'rocks': continue
        pos, n, rr = fx['pos'], max(3, int(fx['scale'])), fx['radius']
        for i in range(n):
            an = math.pi * (i + 0.5) / n
            bx, bz = pos[0] + math.cos(an)*rr, pos[2] - math.sin(an)*rr
            h = 3 + ((i*37) % 7) * 0.7
            pts3 = [(bx-0.6, 0, bz), (bx+0.6, 0, bz), (bx+0.5, h, bz), (bx-0.5, h, bz)]
            pp = [proj(p) for p in pts3]
            if all(pp):
                faces.append((dot(sub((bx, h/2, bz), cam), fwd), [q[:2] for q in pp], (110,98,88), False))
    for fx in fr['fx']:
        if fx['kind'] != 'rockLine': continue
        n, fr0, to = max(1, int(fx['scale'])), fx['from'], fx['to']
        for i in range(n):
            if fx['age'] < i * 3: continue
            t = (i + 0.5) / n
            bx, bz = fr0[0] + (to[0]-fr0[0])*t, fr0[2] + (to[2]-fr0[2])*t
            h = 2 + 3.2 * (i + 1) / n
            pts3 = [(bx-0.6, 0, bz), (bx+0.6, 0, bz), (bx+0.45, h, bz), (bx-0.45, h, bz)]
            pp = [proj(p) for p in pts3]
            if all(pp):
                faces.append((dot(sub((bx, h/2, bz), cam), fwd), [q[:2] for q in pp], (110,98,88), False))
    faces.sort(key=lambda x: -x[0])
    for depth, pts, col, ghost in faces:
        d.polygon(pts, fill=col + (255,), outline=(11,11,14,255))
    # effects
    for fx in fr['fx']:
        age, col, k = fx['age'], fx['color'], fx['kind']
        a = max(40, 255 - age*14) if k not in ('gate','crescent','kanjiSeal','rocks','eclipse','orbs','waterspout') else 220
        if k == 'wake': a = int(max(30, 230 * (1 - age / max(1, fx['life'] * 60))))
        rgba = col + (a,)
        pos = fx['pos']
        def poly3(pts3, width=3, close=False):
            pp = [proj(p) for p in pts3]
            pp = [p[:2] for p in pp if p]
            if len(pp) > 1: d.line(pp + ([pp[0]] if close else []), fill=rgba, width=width)
        if k == 'spark':
            s = 1.0 * fx['scale'] * (1 + age*0.08)
            for i in range(10):
                an = i/10*2*math.pi
                poly3([pos, (pos[0]+math.cos(an)*s, pos[1]+math.sin(an)*s, pos[2])], 2)
        elif k == 'shockwave':
            rr = 1 + age*0.9
            poly3([(pos[0]+math.cos(t/24*2*math.pi)*rr, 0.1, math.sin(t/24*2*math.pi)*rr) for t in range(25)], 3)
        elif k == 'tornadoRing':
            rr = 2.4 + age*0.12
            poly3([(pos[0]+math.cos(t/24*2*math.pi)*rr, pos[1], pos[2]+math.sin(t/24*2*math.pi)*rr) for t in range(25)], 3)
        elif k == 'dragonHelix':
            poly3([(pos[0]+math.cos(t*0.5)*1.6, pos[1]+t*0.3, pos[2]+math.sin(t*0.5)*1.6) for t in range(45)], 4)
        elif k == 'lightning':
            fr0, to = fx['from'], fx['to']
            pts3 = []
            for i in range(9):
                t = i/8
                j = 0 if i in (0,8) else (0.6 if i%2 else -0.6)
                pts3.append((fr0[0]+(to[0]-fr0[0])*t + j*0.5, fr0[1]+(to[1]-fr0[1])*t + j, fr0[2]+(to[2]-fr0[2])*t))
            poly3(pts3, 3)
        elif k == 'arc':
            ct, st = math.cos(fx['tilt']), math.sin(fx['tilt'])
            dirx = 1 if fx['scale'] >= 0 else -1
            fr0, to = fx['from'][0], fx['to'][0]
            # from/to were packed as vectors; the dump keeps degrees in .x of from/to only if numbers
            poly3([(pos[0]+dirx*math.cos(math.radians(an))*fx['radius'], pos[1]+math.sin(math.radians(an))*fx['radius']*ct,
                    pos[2]+math.sin(math.radians(an))*fx['radius']*st) for an in range(int(min(fr0,to)), int(max(fr0,to))+1, 10)], 4)
        elif k == 'crescent':
            poly3([(pos[0]+math.cos(t/20*math.pi+0.3)*4, pos[1]+math.sin(t/20*math.pi+0.3)*4, pos[2]) for t in range(21)], 6)
        elif k == 'kanjiSeal':
            poly3([(pos[0]+math.cos(t/24*2*math.pi)*3, 0.05, math.sin(t/24*2*math.pi)*3) for t in range(25)], 3)
        elif k == 'gate':
            x, z = pos[0], pos[2]
            for dx in (-4, 4): poly3([(x+dx, 0, z), (x+dx, 9, z)], 6)
            poly3([(x-6, 9.5, z), (x+6, 9.5, z)], 7); poly3([(x-5, 7.8, z), (x+5, 7.8, z)], 4)
        elif k == 'dust':
            p = proj(pos)
            if p: d.ellipse([p[0]-8, p[1]-4, p[0]+8, p[1]+4], fill=(200,190,190,a//2))
        elif k == 'smoke':
            p = proj((pos[0], pos[1] + age*0.08, pos[2]))
            if p: d.ellipse([p[0]-6, p[1]-6, p[0]+6, p[1]+6], fill=(140,138,144,a//2))
        elif k == 'debris':
            s = fx['scale']
            for i in range(7):
                an = i * 0.9
                pr = (pos[0] + math.cos(an)*age*0.25*s, pos[1] + age*0.35*s - (age*0.06)**2*4, pos[2] + math.sin(an)*0.6)
                p = proj(pr)
                if p: d.rectangle([p[0]-3, p[1]-3, p[0]+3, p[1]+3], fill=(122,109,98,a))
        elif k == 'crack':
            fr0, to = fx['from'], fx['to']
            pts3 = []
            for i in range(8):
                t = i/7
                j = 0 if i in (0,7) else (0.35 if i%2 else -0.35)
                pts3.append((fr0[0]+(to[0]-fr0[0])*t + j, 0.05, fr0[2]+(to[2]-fr0[2])*t - j))
            poly3(pts3, 3)
        elif k == 'cut':
            poly3([fx['from'], fx['to']], 5)
            rgba = (255,255,255,a)
            poly3([fx['from'], fx['to']], 2)
        elif k == 'rageFist':
            # the giant fist of ki flies from `from` to `to` in a few ticks
            fr0, to = fx['from'], fx['to']
            t = min(1, age / 8)
            tip = tuple(fr0[i] + (to[i]-fr0[i])*t for i in range(3))
            ln = math.sqrt(sum((to[i]-fr0[i])**2 for i in range(3))) or 1
            back = tuple(tip[i] - (to[i]-fr0[i]) / ln * 3.2 * fx['scale'] for i in range(3))
            pb, pt = proj(back), proj(tip)
            if pb and pt:
                edge = proj((tip[0], tip[1] + 1.1*fx['scale'], tip[2]))
                r = abs(edge[1] - pt[1]) if edge else 10
                d.line([pb[:2], pt[:2]], fill=col + (150,), width=max(3, int(r)))
                d.rectangle([pt[0]-r, pt[1]-r, pt[0]+r, pt[1]+r], fill=col + (170,), outline=(255,255,255,200))
        elif k == 'orbs':
            n = max(1, int(fx['scale']))
            for i in range(n):
                an = (fx['phase'] + fx['spin'] * age / 60 + i / n) * 2 * math.pi
                q = (pos[0] + math.cos(an)*fx['radius'], pos[1] + math.sin(an)*fx['radius']*math.sin(fx['tilt']),
                     pos[2] + math.sin(an)*fx['radius']*math.cos(fx['tilt']))
                p, edge = proj(q), proj((q[0], q[1] + 0.55, q[2]))
                if p and edge:
                    r = max(2, abs(edge[1] - p[1]))
                    d.ellipse([p[0]-r*1.4, p[1]-r*1.4, p[0]+r*1.4, p[1]+r*1.4], fill=col + (120,))
                    d.ellipse([p[0]-r, p[1]-r, p[0]+r, p[1]+r], fill=(11,7,18,255))
        elif k == 'orbDart':
            if age <= 6:
                t = min(1, age / 5)
                head = tuple(fx['from'][i] + (fx['to'][i]-fx['from'][i])*t for i in range(3))
                poly3([fx['from'], head], 3)
                p = proj(head)
                if p: d.ellipse([p[0]-5, p[1]-5, p[0]+5, p[1]+5], fill=(11,7,18,255), outline=col + (255,))
        elif k == 'wake':
            poly3([fx['from'], fx['to']], 6)
        elif k == 'waterspout':
            hgt = fx['scale'] * min(1, age / 30)
            rr = fx['radius']
            y = 0.0
            while y <= hgt:
                poly3([(pos[0]+math.cos(t/16*2*math.pi + y)*rr, y, pos[2]+math.sin(t/16*2*math.pi + y)*rr) for t in range(17)], 2)
                y += 1.3
            for sx in (-rr, rr): poly3([(pos[0]+sx, 0, pos[2]), (pos[0]+sx*0.8, hgt, pos[2])], 2)
        elif k == 'eclipse':
            p, edge = proj(pos), proj((pos[0] + 4.5*fx['scale'], pos[1], pos[2]))
            if p and edge:
                r = abs(edge[0] - p[0]) or 4
                d.ellipse([p[0]-r*1.18, p[1]-r*1.18, p[0]+r*1.18, p[1]+r*1.18], fill=col + (150,))
                d.ellipse([p[0]-r, p[1]-r, p[0]+r, p[1]+r], fill=(7,4,12,255))
    g = fr['grade'] + '0000000000'
    if g[2] == '1': img = img.convert('L').convert('RGB')
    elif g[1] == '1': img = Image.blend(img, Image.new('RGB', (W,H), (120,10,20)), 0.45)
    elif g[0] == '1': img = Image.blend(img, Image.new('RGB', (W,H), (255,120,125)), 0.25)
    if g[2] != '1':
        if g[3] == '1': img = Image.blend(img, Image.new('RGB', (W,H), (255,150,60)), 0.28)   # fire
        if g[4] == '1': img = Image.blend(img, Image.new('RGB', (W,H), (150,210,255)), 0.3)   # sky
        if g[5] == '1': img = Image.blend(img, Image.new('RGB', (W,H), (40,20,70)), 0.45)     # shadow
        if g[6] == '1': img = Image.blend(img, Image.new('RGB', (W,H), (255,90,60)), 0.3)     # rage
        if g[7] == '1': img = Image.blend(img, Image.new('RGB', (W,H), (120,170,215)), 0.35)  # current
        if g[8] == '1': img = Image.blend(img, Image.new('RGB', (W,H), (120,30,170)), 0.42)   # inverse
        if g[9] == '1': img = Image.blend(img, Image.new('RGB', (W,H), (190,160,110)), 0.38)  # ruin
    d = ImageDraw.Draw(img, 'RGBA')
    if fr.get('speed'):
        for i in range(28):
            an = i / 28 * 2 * math.pi + (fr['tick'] % 7) * 0.05
            r0 = 0.55 * W
            d.line([(W/2 + math.cos(an)*r0, H/2 + math.sin(an)*r0*0.6), (W/2 + math.cos(an)*W, H/2 + math.sin(an)*W*0.6)],
                   fill=(255,255,255,90), width=2)
    bar = int(H*0.12)
    d.rectangle([0,0,W,bar], fill=(11,11,14)); d.rectangle([0,H-bar,W,H], fill=(11,11,14))
    d.text((4, 2), label, fill=(255,210,63))
    if fr['title'] != '-': d.text((W/2-60, H/2), fr['title'], fill=(255,60,60))
    return img

def sheet(frames, out, cols=5, title=''):
    rows = (len(frames)+cols-1)//cols
    img = Image.new('RGB', (cols*W + (cols+1)*4, rows*H + (rows+1)*4 + 18), (20,20,24))
    ImageDraw.Draw(img).text((6, 3), title, fill=(255,255,255))
    for i, fr in enumerate(frames):
        im = render_frame(fr, f"t{fr['tick']} {fr['shot']}")
        img.paste(im, (4 + (i%cols)*(W+4), 22 + (i//cols)*(H+4)))
    img.save(out)

if __name__ == '__main__':
    frames = parse(sys.argv[1])
    sheet(frames, sys.argv[2], int(os.environ.get('STORY_COLS', '5')), sys.argv[3] if len(sys.argv) > 3 else '')
