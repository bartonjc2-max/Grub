"""Minute-step simulation of the Burrow stat rules (spec: docs/superpowers/specs/2026-11-10-burrow-mechanics-design.md)."""
import random, sys
FOOD={'berry':30,'root':15,'mushroom':15,'honeydew':10}
DECOR={'crystal':8,'shell':8,'amber':7,'bone':7}
ALL={**FOOD,**DECOR}
def run(visits, rules, days=10, seed=1):
    rnd=random.Random(seed)
    s=dict(belly=6,joy=6,molt=0,digs=3,buried=['berry','root','crystal'],bag={'berry':1},placed=0,
           t=dict(dig=0,bury=0,belly=0,joy=0,happy=0),lastpet=-10**9)
    log=dict(sulk=0,joyhi=0,joylo=0,feeds=0,pets=0,dug=0,molt_day=None,too_full=0,nofood=0,decor=0)
    for m in range(days*24*60):
        # timers (1-minute step)
        dp=rules['dig_period'](s)
        if s['digs']<3:
            s['t']['dig']+=1
            if s['t']['dig']>=dp: s['t']['dig']=0; s['digs']+=1
        else: s['t']['dig']=0
        if len(s['buried'])<4:
            s['t']['bury']+=1
            if s['t']['bury']>=120:
                s['t']['bury']=0; s['buried'].append(rnd.choices(list(ALL),list(ALL.values()))[0])
        else: s['t']['bury']=0
        if s['belly']>0:
            s['t']['belly']+=1
            if s['t']['belly']>=120: s['t']['belly']=0; s['belly']-=1
        jp=60 if s['belly']==0 else rules['joy_period'](s)
        if s['joy']>0:
            s['t']['joy']+=1
            if s['t']['joy']>=jp: s['t']['joy']=0; s['joy']-=1
        if rules['happy'] and s['joy']>=6 and s['belly']>0 and s['molt']<rules['goal']:
            s['t']['happy']+=1
            if s['t']['happy']>=720: s['t']['happy']=0; s['molt']+=1
        if s['belly']==0: log['sulk']+=1
        if s['joy']>=7: log['joyhi']+=1
        if s['joy']<=2: log['joylo']+=1
        # visit
        hour=(m//60)%24
        if (m%1440) in visits_min(visits):
            while s['digs']>0 and s['buried']:
                k=s['buried'].pop(0); s['digs']-=1; s['bag'][k]=s['bag'].get(k,0)+1; log['dug']+=1
                if s['joy']>=7 and rnd.random()<rules.get('bonus',0):
                    b=rnd.choices(list(ALL),list(ALL.values()))[0]; s['bag'][b]=s['bag'].get(b,0)+1; log['dug']+=1
            # place decor
            for k in list(DECOR):
                while s['bag'].get(k,0)>0 and s['placed']<4:
                    s['bag'][k]-=1; s['placed']+=1; log['decor']+=1
            # feed while belly<=7
            while s['belly']<=7:
                f=next((k for k in FOOD if s['bag'].get(k,0)>0 and k!=s.get('last')),None) or next((k for k in FOOD if s['bag'].get(k,0)>0),None)
                if not f: log['nofood']+=1; break
                s['bag'][f]-=1; s['belly']=min(10,s['belly']+3); s['molt']=min(rules['goal'],s['molt']+1)
                s['joy']=min(10,s['joy']+(rules['feed_joy'] if f!=s.get('last') else 0)); s['last']=f; log['feeds']+=1
            if m-s['lastpet']>=15:
                s['joy']=min(10,s['joy']+1); s['lastpet']=m; log['pets']+=1
        if s['molt']>=rules['goal'] and log['molt_day'] is None: log['molt_day']=round(m/1440,2)
    tot=days*1440
    return dict(molt_day=log['molt_day'], sulk_pct=round(100*log['sulk']/tot), joy_hi_pct=round(100*log['joyhi']/tot),
                joy_lo_pct=round(100*log['joylo']/tot), feeds_per_day=round(log['feeds']/days,1), digs_per_day=round(log['dug']/days,1))
VISITS={'4/day':[8*60,12*60,17*60,22*60],'2/day':[8*60,20*60],'1/day':[19*60]}
def visits_min(v): return VISITS[v]
RULES=dict(goal=10, happy=False, feed_joy=1, bonus=0.35, dig_period=lambda s:180, joy_period=lambda s:240+60*s['placed'])
if __name__=="__main__":
    for v in VISITS:
        res=[run(v,RULES,seed=i) for i in range(30)]
        md=[r['molt_day'] or 99 for r in res]
        avg=lambda k: round(sum(r[k] for r in res)/len(res),1)
        print(f"{v}: molt avg {sum(md)/len(md):.1f}d | finds/day={avg('digs_per_day')} meals/day={avg('feeds_per_day')} sulk%={avg('sulk_pct')} happy%={avg('joy_hi_pct')}")
