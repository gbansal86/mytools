#!/usr/bin/env python3
"""Editable offline motion-graphic video script. Full working-cut project/AI images supplied in downloadable companion bundle."""
from pathlib import Path
import argparse, math, subprocess, wave, json
from PIL import Image, ImageDraw, ImageFont
BASE=Path(__file__).resolve().parent
ASSETS=BASE/"assets"
TMP=BASE/"scenes"
AUDIO=BASE/"audio"
OUT=BASE/"output"
for p in (TMP,AUDIO,OUT): p.mkdir(exist_ok=True)
W,H=1280,720
FONT="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_WIN="C:/Windows/Fonts/arialbd.ttf"
def ft(n):
    p=FONT if Path(FONT).exists() else FONT_WIN
    return ImageFont.truetype(p,n)
NAVY="#07192b"; GOLD="#ffd06b"; CYAN="#7bdcec"; WHITE="#f8fcff"
TOPICS=[
("TRUMP / RUSSIAN OIL / INDIA","WHAT HAPPENED AT THE UN?",
 "A new American law, Russian oil shipments, and India’s diplomacy appear in the same headlines. What actually happened at the United Nations?"),
("THREE COUNTRIES, THREE ROLES","RUSSIA     →     INDIA     ↔     USA",
 "Russia supplies oil. India seeks reliable energy. The United States uses sanctions and tariffs in response to the war in Ukraine."),
("18 SEPTEMBER 2026","AUTHORITY IS NOT APPLICATION",
 "President Trump signed the Russia and Iran sanctions law. It gives tariff authority but does not by itself establish a new one hundred percent tariff on India."),
("RUSSIAN CRUDE / INDIA","ENERGY SUPPLY DECISIONS",
 "India imports crude oil from Russia, and its refiners can source oil elsewhere. An oil import and a tariff on Indian goods exported to America are different things."),
("THE POLICY DECISION","LAW  →  RATE  →  SCOPE  →  DATE",
 "A law authorises measures. A separate decision determines whether a tariff applies, to what goods, and when. Check implementation before repeating a headline."),
("JAISHANKAR / MARCO RUBIO","BILATERAL MEETING — 23 SEPTEMBER",
 "India raised its interests and concerns at a meeting with the US Secretary of State in New York on the sidelines of the General Assembly."),
("INDIA'S BROADER UN MESSAGE","FUEL  •  FOOD  •  FERTILISERS  •  FINANCE",
 "India raised concerns about international economic resilience and developing countries. This wider agenda is not the same as the bilateral US tariff discussion."),
("WHAT CAN THE UN DO?","GENERAL ASSEMBLY ≠ SECURITY COUNCIL",
 "The General Assembly provides a forum for diplomacy. The Security Council has a separate peace and security role. Neither automatically sets US tariffs or India's oil orders."),
("FACT-CHECK EACH DEVELOPMENT","SIGNED  →  DISCUSSED  →  APPLIED?",
 "Separate these events. A law was signed. Diplomatic concerns were discussed. Any new tariff actually imposed on India requires separate dated verification."),
("WHAT WE KNOW","FOLLOW THE NEXT VERIFIED DECISION",
 "The story links Russian energy exports, American economic policy, and India's energy and trade interests. The UN meetings offered a place for diplomatic discussion.")
]
def call(cmd):
    subprocess.run([str(c) for c in cmd],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
def arrow(d,a,b,colour=GOLD):
    d.line((a[0],a[1],b[0],b[1]),fill=colour,width=9)
    q=math.atan2(b[1]-a[1],b[0]-a[0])
    d.polygon([b,(b[0]-24*math.cos(q-.5),b[1]-24*math.sin(q-.5)),
               (b[0]-24*math.cos(q+.5),b[1]-24*math.sin(q+.5))],fill=colour)
def card(d,xy,t,sub,accent=CYAN):
    d.rounded_rectangle(xy,26,fill="#19344a",outline="#5082a0",width=3)
    x,y,x2,_=xy
    d.ellipse((x+26,y+27,x+42,y+43),fill=accent)
    d.text((x+58,y+20),t,font=ft(27),fill=WHITE)
    d.text((x+28,y+81),sub,font=ft(20),fill="#b9cedd")
def paint(i,stage):
    im=Image.new("RGB",(W,H),NAVY);d=ImageDraw.Draw(im)
    for x in range(0,W,90):d.line((x,0,x,H),fill="#122e42")
    for y in range(0,H,90):d.line((0,y,W,y),fill="#122e42")
    # A real, clearly labelled composite in the first and last scenes.
    src=ASSETS/"ai_un_composite.png"
    if i in (0,9) and src.exists():
        a=Image.open(src).convert("RGB")
        ratio=max(W/a.width,H/a.height)
        a=a.resize((math.ceil(a.width*ratio),math.ceil(a.height*ratio)))
        x=(a.width-W)//2;y=(a.height-H)//2
        im.paste(a.crop((x,y,x+W,y+H)),(0,0))
        d=ImageDraw.Draw(im,"RGBA")
        d.rectangle((0,405,W,720),fill=(3,12,25,223))
        d.text((865,24),"AI EDITORIAL COMPOSITE",font=ft(17),fill=GOLD)
    d=ImageDraw.Draw(im)
    d.text((58,40),f"EXPLAINER  /  {i:02d}",font=ft(20),fill=CYAN)
    headline,sub,_=TOPICS[i]
    d.text((58,82),headline,font=ft(37),fill=WHITE)
    if i in (0,9):
        d.text((59,497),sub,font=ft(41),fill=GOLD)
    else:
        d.text((58,154),sub,font=ft(29),fill=GOLD)
        d.line((58,218,W-58,218),fill="#4f7084",width=2)
        if i==1:
            card(d,(45,273,425,489),"RUSSIA","Crude oil supply")
            card(d,(451,273,831,489),"INDIA","Energy security")
            card(d,(857,273,1237,489),"UNITED STATES","Tariff authority")
            if stage>=1:arrow(d,(425,387),(451,387))
            if stage>=2:arrow(d,(831,387),(857,387))
        elif i in (4,8):
            names=["LAW","DECISION","IMPLEMENTATION"] if i==4 else ["SIGNED","DISCUSSED","APPLIED?"]
            for k,v in enumerate(names):
                x=50+407*k
                card(d,(x,270,x+367,480),v,["First","Next","Verify"][k])
                if k and stage>=k:arrow(d,(x-38,370),(x-9,370))
        elif i==6:
            for k,(t,s) in enumerate([("FUEL","Energy supply"),("FOOD","Food security"),
                                      ("FERTILISERS","Farm inputs"),("FINANCE","Funding")]):
                x=80+575*(k%2);y=245+175*(k//2)
                if stage>=k//2:card(d,(x,y,x+540,y+155),t,s)
        elif i in (2,3,5,7):
            if i==2:
                card(d,(75,265,620,530),"18 SEP 2026","Law signed")
                card(d,(664,265,1206,530),"UP TO 100%","Authorised maximum")
            elif i==3:
                card(d,(75,265,620,530),"RUSSIAN OIL","Crude imports")
                card(d,(664,265,1206,530),"INDIA","Alternative supply options")
            elif i==5:
                card(d,(75,265,620,530),"INDIA","Raised concerns")
                card(d,(664,265,1206,530),"UNITED STATES","Bilateral meeting")
            else:
                card(d,(75,265,620,530),"GENERAL ASSEMBLY","193 UN member states")
                card(d,(664,265,1206,530),"SECURITY COUNCIL","15 member states")
            if stage>=1:arrow(d,(621,397),(660,397))
        d.rounded_rectangle((72,580,1209,653),18,fill="#112d41",outline="#6d91a4",width=2)
        # Short takeaway wraps are supplied in the downloadable full renderer.
        t=["","The UN meeting was not a three-way summit.",
           "Authorised maximum ≠ an actual new tariff.","Oil imports and export tariffs are distinct.",
           "Never confuse an announced power with a completed action.",
           "The Rubio meeting was on the sidelines of UNGA.",
           "India's wider UN agenda covers several economic concerns.",
           "The UN does not automatically set national tariff rates.",
           "Check the date, rate, scope and official announcement.",
           ""][i]
        d.text((97,597),t,font=ft(20),fill=WHITE)
        d.text((60,682),"24 SEPT 2026  •  SOURCE REGISTER IN docs/SOURCES.md",font=ft(16),fill="#a6b7c6")
    return im
def voice(i,text,words_per_min=165):
    path=AUDIO/f"{i:02d}_draft_voice.wav"
    if not path.exists():
        call(["espeak","-v","en-us+m3","-s",words_per_min,"-p",39,"-w",path,text])
    with wave.open(str(path),"rb") as w:return path,w.getnframes()/w.getframerate()
def main():
    a=argparse.ArgumentParser();a.add_argument("--force",action="store_true")
    a.add_argument("--fps",type=int,default=18);opts=a.parse_args()
    clips=[];manifest=[]
    for i,(head,sub,speech) in enumerate(TOPICS):
        audio,secs=voice(i,speech);dur=secs+2.0
        out=TMP/f"scene_{i:02d}.mp4"
        if opts.force or not out.exists():
            chunks=[]
            for stage in range(3):
                still=TMP/f"{i:02d}_{stage}.png";paint(i,stage).save(still)
                part=TMP/f"{i:02d}_{stage}.mp4";n=round(dur*opts.fps/3)
                vf=f"scale=1360:765,zoompan=z='min(zoom+0.00025,1.05)':x='(iw-iw/zoom)/2':y='(ih-ih/zoom)/2':d={n}:s=1280x720:fps={opts.fps},format=yuv420p"
                call(["ffmpeg","-y","-loop","1","-framerate",opts.fps,"-i",still,
                      "-vf",vf,"-frames:v",n,"-an","-c:v","libx264","-preset","ultrafast",
                      "-crf","27","-pix_fmt","yuv420p",part])
                chunks.append(part)
            listfile=TMP/f"parts_{i:02d}.txt"
            listfile.write_text("".join(f"file '{v.name}'\n" for v in chunks))
            temp=TMP/f"visual_{i:02d}.mp4"
            call(["ffmpeg","-y","-f","concat","-safe","0","-i",listfile,"-c","copy",temp])
            call(["ffmpeg","-y","-i",temp,"-i",audio,"-filter_complex","[1:a]apad[a]",
                  "-map","0:v","-map","[a]","-t",dur,"-c:v","copy","-c:a","aac",out])
        clips.append(out);manifest.append(dict(scene=i,text=speech,duration=round(dur,2)))
    listfile=TMP/"all.txt"
    listfile.write_text("".join(f"file '{v.resolve()}'\n" for v in clips))
    final=OUT/"Trump_Russian_Oil_India_UNGA_2026.mp4"
    call(["ffmpeg","-y","-f","concat","-safe","0","-i",listfile,"-c","copy",final])
    (OUT/"scene_manifest.json").write_text(json.dumps(manifest,indent=2))
    print("Working cut:",final)
if __name__=="__main__":main()
