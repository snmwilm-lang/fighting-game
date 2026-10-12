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
            # optional 20th field: the shape (W = WedgePart, else a block)
            frames[-1]['parts'].append((int(f[1]), f[2], nums[:12], nums[12:15], False, hexc(f[18]) if len(f) > 18 else None,
                                        f[19] if len(f) > 19 else 'B'))
        elif f[0] == 'SHAPE' and frames:
            # a finisher's light: kind, a (pos/from), b (to/normal), radius, width, colour, alpha, extra, count
            frames[-1].setdefault('shapes', []).append({'kind': f[1], 'a': tuple(map(float, f[2:5])), 'b': tuple(map(float, f[5:8])),
                'r': float(f[8]), 'w': float(f[9]), 'color': hexc(f[10]), 'alpha': float(f[11]), 'extra': float(f[12]),
                'count': int(float(f[13]))})
        elif f[0] == 'OVERLAY' and frames:
            frames[-1]['overlay'] = {'desat': float(f[1]), 'blur': float(f[2]), 'fp': int(f[3]), 'line': float(f[4]),
                'open': float(f[5]), 'join': float(f[6]), 'angle': float(f[7]), 'color': hexc(f[8]), 'ko': int(f[9]),
                'sub': f[10].replace('_', ' ') if len(f) > 10 else ''}
        elif f[0] == 'TINT' and frames:
            frames[-1]['tint'] = (hexc(f[1]), float(f[2]))
        elif f[0] == 'WHITE' and frames:
            frames[-1]['white'] = float(f[1])
        elif f[0] == 'KOCARD' and frames:
            frames[-1]['kocard'] = (hexc(f[1]), None if f[2] == '-' else hexc(f[2]))
        elif f[0] == 'LETTERS' and frames:
            frames[-1]['letters'] = ['' if x == '-' else x for x in f[1:3]]
        elif f[0] == 'LETTERAT' and frames:
            n = list(map(float, f[1:6]))
            frames[-1]['letterat'] = ((n[0], n[1]), (n[2], n[3]), n[4])
        elif f[0] == 'SPLITONLY' and frames:
            frames[-1]['splitonly'] = (int(f[1]), int(f[2]))
        elif f[0] == 'SPLITVIEW' and frames:
            n = list(map(float, f[2:11]))
            frames[-1].setdefault('splitviews', {})[int(f[1])] = {'fov': n[0], 'roll': n[1], 'cam': (n[2:5], n[5:8])}
        elif f[0] == 'CAPTION' and frames:
            frames[-1]['caption'] = {'text': f[1].replace('_', ' '), 'age': int(f[2]), 'color': hexc(f[3]), 'fade': float(f[4])}
        elif f[0] == 'MATTER' and frames:
            frames[-1].setdefault('matter', []).append({'shape': f[1], 'pos': tuple(map(float, f[2:5])), 'r': float(f[5]),
                'h': float(f[6]), 'n': tuple(map(float, f[7:10])), 'color': hexc(f[10])})
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
    for part in fr['parts']:
        slot, name, t, size, ghost, own = part[:6]
        shape = part[6] if len(part) > 6 else 'B'
        px, py, pz = t[0], t[1], t[2]
        R = [[t[3],t[4],t[5]],[t[6],t[7],t[8]],[t[9],t[10],t[11]]]
        hx, hy, hz = size[0]/2, size[1]/2, size[2]/2
        corners = []
        for sx in (-1,1):
            for sy in (-1,1):
                for sz in (-1,1):
                    lx, ly, lz = sx*hx, sy*hy, sz*hz
                    # a WedgePart: its top front edge comes down to the bottom (the slope rises
                    # from the front-bottom edge to the back-top edge, as in Roblox)
                    if shape == 'W' and sy > 0 and sz < 0: ly = -hy
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
        elif k == 'kiBeam':
            if age <= 24:
                poly3([fx['from'], fx['to']], max(4, int(14 * fx['scale'])))
                rgba = (255,255,255,a)
                poly3([fx['from'], fx['to']], max(2, int(5 * fx['scale'])))
        elif k == 'windBlade':
            if age <= 10:
                t = min(1, age / 5)
                c = tuple(fx['from'][i] + (fx['to'][i]-fx['from'][i])*t for i in range(3))
                s_ = fx['scale']
                poly3([(c[0] + math.sin(an/6*1.1)*0.9*s_ * (1 if fx['to'][0] >= fx['from'][0] else -1) - (1-math.cos(an/6*1.1))*0.5*s_ * (1 if fx['to'][0] >= fx['from'][0] else -1),
                        c[1] + math.sin(an/6*1.1)*1.6*s_*math.cos(fx['tilt']), c[2]) for an in range(-6, 7)], 4)
        elif k == 'ropes':
            for i in range(1, 4):
                lift = 1.2 + i * 1.1
                poly3([(fx['from'][0], lift, fx['from'][2]), (fx['to'][0], lift, fx['to'][2])], 3)
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
    # DAICHA's matter: a black ball, a disc (sampled ring), a puddle, a wave (an upright drop)
    for m in fr.get('matter', []):
        pos, r, col = m['pos'], m['r'], m['color']
        if m['shape'] in ('ball', 'wave'):
            p = proj(pos)
            top = proj((pos[0], pos[1] + (m['h']/2 if m['shape'] == 'wave' else r), pos[2]))
            side = proj((pos[0] + r, pos[1], pos[2]))
            if p and top and side:
                rx = max(2, abs(side[0] - p[0])); ry = max(2, abs(top[1] - p[1]))
                d.ellipse([p[0]-rx-2, p[1]-ry-2, p[0]+rx+2, p[1]+ry+2], fill=col + (140,))
                d.ellipse([p[0]-rx, p[1]-ry, p[0]+rx, p[1]+ry], fill=(11,7,18,255))
        else:
            n = m['n'] if m['shape'] == 'disc' else (0.0, 1.0, 0.0)
            nn = norm(n)
            ref = (1.0, 0.0, 0.0) if abs(nn[1]) > 0.9 else (0.0, 1.0, 0.0)
            u = norm(cross(ref, nn)); w = cross(nn, u)
            pts = [proj((pos[0] + (u[0]*math.cos(t) + w[0]*math.sin(t))*r, pos[1] + (u[1]*math.cos(t) + w[1]*math.sin(t))*r,
                         pos[2] + (u[2]*math.cos(t) + w[2]*math.sin(t))*r)) for t in [i/24*2*math.pi for i in range(24)]]
            if all(pts):
                d.polygon([q[:2] for q in pts], fill=(11,7,18,235), outline=col + (230,))
    # a finisher's light: balls of energy, the ray, rings, motes, blade streaks, the blast's shell
    def size_at(p3, r):
        p, e = proj(p3), proj((p3[0], p3[1] + r, p3[2]))
        if not p or not e: return None, 0
        return p, max(1.5, abs(e[1] - p[1]))
    for sh in fr.get('shapes', []):
        k, col, a3, b3 = sh['kind'], sh['color'], sh['a'], sh['b']
        if k == 'sphere':
            p, r = size_at(a3, sh['r'])
            if p:
                d.ellipse([p[0]-r*1.6, p[1]-r*1.6, p[0]+r*1.6, p[1]+r*1.6], fill=col + (70,))
                d.ellipse([p[0]-r, p[1]-r, p[0]+r, p[1]+r], fill=col + (200,))
                c = r * 0.6 * max(0.2, sh['extra'])
                d.ellipse([p[0]-c, p[1]-c, p[0]+c, p[1]+c], fill=(255,255,255,230))
        elif k == 'beam':
            # (clipped to the camera's near plane: a ray seen along its axis still shows)
            def clip(p0, p1):
                z0, z1 = dot(sub(p0, cam), fwd), dot(sub(p1, cam), fwd)
                if z0 >= 0.2 and z1 >= 0.2: return p0, p1
                if z0 < 0.2 and z1 < 0.2: return None, None
                t = (0.2 - z0) / (z1 - z0)
                q = tuple(p0[i] + (p1[i] - p0[i]) * t for i in range(3))
                return (q, p1) if z0 < 0.2 else (p0, q)
            ca, cb = clip(a3, b3)
            pa, pb = (proj(ca), proj(cb)) if ca else (None, None)
            if pa and pb:
                mid = tuple((a3[i] + b3[i]) / 2 for i in range(3))
                _, r = size_at(mid, sh['r'])
                d.line([pa[:2], pb[:2]], fill=col + (120,), width=max(3, int(r * 2.6)))
                d.line([pa[:2], pb[:2]], fill=col + (220,), width=max(2, int(r * 1.6)))
                d.line([pa[:2], pb[:2]], fill=(255,255,255,235), width=max(1, int(r * 0.7)))
                for i in range(5):
                    t = ((sh['extra'] + i / 5) % 1)
                    q = tuple(a3[j] + (b3[j] - a3[j]) * t for j in range(3))
                    p, rr = size_at(q, sh['r'] * 1.3)
                    if p: d.ellipse([p[0]-rr*0.35, p[1]-rr, p[0]+rr*0.35, p[1]+rr], outline=(255,255,255,200), width=2)
        elif k in ('ring', 'dome'):
            n = norm(b3) if k == 'ring' else (0.0, 1.0, 0.0)
            ref = (1.0, 0.0, 0.0) if abs(n[1]) > 0.9 else (0.0, 1.0, 0.0)
            u = norm(cross(ref, n)); w = cross(n, u)
            alpha = int(255 * (1 - sh['alpha']))
            if k == 'ring':
                pts = [proj(tuple(a3[i] + (u[i]*math.cos(t) + w[i]*math.sin(t)) * sh['r'] for i in range(3)))
                       for t in [j/32*2*math.pi for j in range(33)]]
                pts = [q[:2] for q in pts if q]
                if len(pts) > 1: d.line(pts, fill=col + (alpha,), width=max(2, int(sh['w'] * 10)))
            else:
                p, r = size_at(a3, sh['r'])
                if p: d.pieslice([p[0]-r, p[1]-r, p[0]+r, p[1]+r], 180, 360, fill=col + (alpha // 2,), outline=(255,255,255,alpha))
        elif k == 'motes':
            n = max(1, sh['count'])
            for i in range(n):
                t = (sh['extra'] * 0.6 + i / n) % 1
                rr = sh['r'] * ((t) if sh['w'] == 0 else t)
                an = i * 2.4 + sh['extra'] * 3
                q = (a3[0] + math.cos(an) * rr, a3[1] + math.sin(an * 1.3) * rr * 0.6, a3[2] + math.sin(an) * rr)
                p = proj(q)
                if p: d.ellipse([p[0]-2, p[1]-2, p[0]+2, p[1]+2], fill=col + (220,))
        elif k == 'slash':
            pa, pb = proj(a3), proj(b3)
            if pa and pb:
                alpha = int(255 * (1 - sh['alpha']))
                d.line([pa[:2], pb[:2]], fill=col + (alpha,), width=max(1, int(sh['w'] * 30)))
                d.line([pa[:2], pb[:2]], fill=(255,255,255,alpha), width=max(1, int(sh['w'] * 10)))
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
    if fr.get('tint'):
        # a night tint: the colour over the scene, darker
        col, amt = fr['tint']
        img = Image.blend(img, Image.new('RGB', (W, H), col), 0.45 * amt)
        img = Image.blend(img, Image.new('RGB', (W, H), (0, 0, 0)), 0.25 * amt)
        d = ImageDraw.Draw(img, 'RGBA')
    ov = fr.get('overlay')
    if ov:
        if ov['desat'] > 0:
            img = Image.blend(img, img.convert('L').convert('RGB'), min(1, ov['desat']))
        if ov['blur'] > 0.05:
            from PIL import ImageFilter
            img = img.filter(ImageFilter.GaussianBlur(radius=ov['blur'] * W / 120))
        if ov['line'] >= 0:
            halves = None
            if fr.get('splitviews') and (ov['open'] > 0.001 or ov['join'] > 0.001):
                # each half its own shot (SHIN behind the K, the target behind the O)
                halves = []
                for side in (1, 2):
                    sv = fr['splitviews'].get(side)
                    copy = dict(fr)
                    for k in ('overlay', 'splitviews', 'caption', 'kocard', 'white'): copy.pop(k, None)
                    if sv: copy['cam'], copy['fov'], copy['roll'] = sv['cam'], sv['fov'], sv['roll']
                    only = fr.get('splitonly')
                    if only and only[side - 1]: copy['parts'] = [p for p in fr['parts'] if p[0] == only[side - 1]]
                    halves.append(render_frame(copy, ''))
            img = split_screen(img, ov, halves, fr.get('letters'), fr.get('letterat'))
        d = ImageDraw.Draw(img, 'RGBA')
        if fr.get('white'):
            img = Image.blend(img, Image.new('RGB', (W, H), (255, 255, 255)), min(1, fr['white']))
            d = ImageDraw.Draw(img, 'RGBA')
        if fr.get('kocard'):
            # the K.O. card: the whole screen one colour, a splash behind the letters
            bg, splash = fr['kocard']
            d.rectangle([0, 0, W, H], fill=bg + (255,))
            if splash:
                for i in range(3):
                    a = math.radians(-18 + (i - 1) * 9)
                    cx_, cy_, L_, T_ = W * (0.5 + (i - 1) * 0.05), H * (0.45 + (i - 1) * 0.04), W * (0.45 - abs(i - 1) * 0.1), H * (0.025 - abs(i - 1) * 0.007)
                    dx, dy, nx_, ny_ = math.cos(a) * L_, math.sin(a) * L_, -math.sin(a) * T_, math.cos(a) * T_
                    d.polygon([(cx_ - dx - nx_, cy_ - dy - ny_), (cx_ + dx - nx_, cy_ + dy - ny_), (cx_ + dx + nx_, cy_ + dy + ny_), (cx_ - dx + nx_, cy_ - dy + ny_)], fill=splash + (255,))
                for i in range(4, 10):
                    px_, py_ = W * (0.5 + math.cos(i * 1.7) * 0.32), H * (0.45 + math.sin(i * 1.3) * 0.28)
                    d.ellipse([px_ - 4, py_ - 4, px_ + 4, py_ + 4], fill=splash + (255,))
        if ov['ko'] >= 0:
            big, small = font(int(H * 0.34)), font(int(H * 0.07))
            age = ov['ko']
            s_ = 1 + max(0, 6 - age) * 0.12
            settle = 0 if fr.get('kocard') else min(1, max(0, (age - 40) / 20))   # (after its slam it rises and shrinks: the scene reads)
            size = 0.34 - 0.18 * settle
            y = H * (0.42 - 0.22 * settle)
            draw_center(d, 'K.O.', W/2, y, font(int(H * size * s_)), (255,255,255), ov['color'])
            draw_center(d, ov['sub'], W/2, y + H * (0.26 - 0.12 * settle), small, ov['color'], (11,11,14))
        cap = fr.get('caption')
        if cap and cap['fade'] < 1:
            # a count slammed in at the side (RYUKEN's ten fists of rage)
            s_ = 1 + max(0, 6 - cap['age']) * 0.13
            a_ = int(255 * (1 - cap['fade']))
            c_ = cap['color'] + (a_,) if len(cap['color']) == 3 else cap['color']
            draw_center(d, cap['text'], W * 0.85, H * 0.5, font(int(H * 0.26 * s_)), c_, (11,11,14,a_))
        if ov['fp']:
            d.text((W - 92, H*0.14), 'FIRST PERSON', fill=(255,255,255,200))
        d = ImageDraw.Draw(img, 'RGBA')
    bar = int(H*0.12)
    d.rectangle([0,0,W,bar], fill=(11,11,14)); d.rectangle([0,H-bar,W,H], fill=(11,11,14))
    d.text((4, 2), label, fill=(255,210,63))
    if fr['title'] != '-': d.text((W/2-60, H/2), fr['title'], fill=(255,60,60))
    return img

def font(size):
    for f in ('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',):
        try: return ImageFont.truetype(f, max(6, size))
        except Exception: pass
    return ImageFont.load_default()

def draw_center(d, text, x, y, fnt, fill, stroke):
    box = d.textbbox((0, 0), text, font=fnt)
    w, h = box[2] - box[0], box[3] - box[1]
    d.text((x - w/2, y - h/2 - box[1]), text, font=fnt, fill=fill, stroke_width=max(1, h // 14), stroke_fill=stroke)

# SHIN's FINAL DIVISION: the image cut along a line (angle in degrees, the line drawn `line` of
# the way), the halves slid apart along it (`open`), K in one, O in the other; `join` brings
# the letters together into K.O.
def split_screen(img, ov, halves=None, letters=None, letterat=None):
    # (the angle turns clockwise on the screen, as a Roblox Rotation: the line travels along u,
    # the first half lies on its left-hand side n, the second on the other)
    an = math.radians(ov['angle'])
    ux, uy = math.cos(an), math.sin(an)            # along the line (screen space, y down)
    nx, ny = -uy, ux                               # toward the first half
    cx, cy = W / 2, H / 2
    mask = Image.new('L', (W, H), 0)
    md = ImageDraw.Draw(mask)
    far = W * 2
    md.polygon([(cx - ux*far, cy - uy*far), (cx + ux*far, cy + uy*far),
                (cx + ux*far + nx*far, cy + uy*far + ny*far), (cx - ux*far + nx*far, cy - uy*far + ny*far)], fill=255)
    out = img.copy()
    if ov['open'] > 0.001 or halves:
        shift = 0 if halves else ov['open'] * W * 0.07
        src_a, src_b = (halves[0], halves[1]) if halves else (img, img)
        a = src_a.transform(img.size, Image.AFFINE, (1, 0, ux*shift, 0, 1, uy*shift))
        b = src_b.transform(img.size, Image.AFFINE, (1, 0, -ux*shift, 0, 1, -uy*shift))
        out = Image.composite(a, b, mask)
    d = ImageDraw.Draw(out, 'RGBA')
    if ov['open'] > 0.001 or ov['join'] > 0.001:
        gap = ov['open'] * W * (0.008 if halves else 0.015)
        d.line([(cx - ux*far, cy - uy*far), (cx + ux*far, cy + uy*far)], fill=(8,8,10,255), width=max(2, int(gap*2)))
        jn = ov['join']
        (k_at, o_at, size) = letterat or ((0.3, 0.36), (0.7, 0.64), 0.4)
        fk = font(int(H * size * (1 - 0.3*jn)))
        lk, lo = (letters or ['K', 'O'])[0], (letters or ['K', 'O'])[1]
        # (apart, each in its half; joined, side by side in the middle: K.O.)
        kx, ky = k_at[0] + (0.42 - k_at[0]) * jn, k_at[1] + (0.5 - k_at[1]) * jn
        ox, oy = o_at[0] + (0.58 - o_at[0]) * jn, o_at[1] + (0.5 - o_at[1]) * jn
        if lk: draw_center(d, lk, kx * W, ky * H, fk, (255,255,255,230), ov['color'])
        if lo: draw_center(d, lo, ox * W, oy * H, fk, (255,255,255,230), ov['color'])
        if jn > 0.95: draw_center(d, '.', cx, cy + H*0.08, fk, (255,255,255,230), ov['color'])
    t = max(0, min(1, ov['line']))
    if t > 0:
        a0 = (cx - ux*W*0.75, cy - uy*W*0.75)
        a1 = (a0[0] + ux*W*1.5*t, a0[1] + uy*W*1.5*t)
        d.line([a0, a1], fill=ov['color'] + (160,), width=7)
        d.line([a0, a1], fill=(255,255,255,255), width=3)
    return out

def sheet(frames, out, cols=5, title=''):
    rows = (len(frames)+cols-1)//cols
    img = Image.new('RGB', (cols*W + (cols+1)*4, rows*H + (rows+1)*4 + 18), (20,20,24))
    ImageDraw.Draw(img).text((6, 3), title, fill=(255,255,255))
    for i, fr in enumerate(frames):
        im = render_frame(fr, f"t{fr['tick']} {fr['shot']}")
        img.paste(im, (4 + (i%cols)*(W+4), 22 + (i//cols)*(H+4)))
    img.save(out)

def gif(frames, out, step_ms):
    # An animated clip (tests/AnimClip.luau): one image per frame, at the clip's own rate.
    images = [render_frame(fr, fr['shot']).convert('P', palette=Image.ADAPTIVE, colors=128) for fr in frames]
    images[0].save(out, save_all=True, append_images=images[1:], duration=step_ms, loop=0, optimize=False)

if __name__ == '__main__':
    frames = parse(sys.argv[1])
    if sys.argv[2].endswith('.gif'):
        ticks = [fr['tick'] for fr in frames]
        step = (ticks[1] - ticks[0]) if len(ticks) > 1 else 2
        gif(frames, sys.argv[2], int(round(step * 1000 / 60 * float(os.environ.get('STORY_SLOW', '1')))))
    else:
        # (STORY_FROM / STORY_TO / STORY_EVERY: a slice of the frames, e.g. one move of a clip)
        lo, hi = int(os.environ.get('STORY_FROM', '0')), int(os.environ.get('STORY_TO', '100000'))
        every = int(os.environ.get('STORY_EVERY', '1'))
        frames = [fr for fr in frames if lo <= fr['tick'] <= hi][::every]
        sheet(frames, sys.argv[2], int(os.environ.get('STORY_COLS', '5')), sys.argv[3] if len(sys.argv) > 3 else '')
