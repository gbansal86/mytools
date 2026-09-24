#!/usr/bin/env python3
"""Render an original silent, animated educational Short ANIMATIC.

This is a motion/timing prototype, NOT final narration, licensed music, polished 3D,
or a finished video. Requires numpy, opencv-python, Pillow, ffmpeg.
"""
from __future__ import annotations
import argparse
import math
import subprocess
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

W, H, FPS, TOTAL = 720, 1280, 24, 60
NAVY=(23,40,65); MUTED=(88,105,123); BLUE=(40,114,206); ORANGE=(232,128,56); GREEN=(38,157,122); RED=(209,78,85)
CREAM=(251,249,244); WHITE=(255,255,255); BG=(236,244,251)
SCENES=[
 (0,5,'THE QUESTION','How can AI answer so quickly?','It usually learned long before you asked.'),
 (5,12,'TWO DIFFERENT STAGES','Training  /  Using a trained model','Learning happens first. A new task comes later.'),
 (12,22,'STAGE 1: TRAINING','Many labeled examples go in','Spam and genuine emails teach useful patterns.'),
 (22,30,'PATTERNS, NOT MAGIC','Training adjusts model parameters','The model gets better at the task.'),
 (30,39,'STAGE 2: USING AI','A new email goes into the trained model','The output is a prediction, not a certainty.'),
 (39,48,'GENERATIVE AI','Prompt in. New text out.','Training first; generation when you ask.'),
 (48,55,'IMPORTANT: CHECK','A confident answer can be wrong','Verify important claims with reliable sources.'),
 (55,60,'REMEMBER THE TWO STAGES','TRAINING  ->  USING  ->  CHECK','Learn patterns. Produce output. Check results.'),
]
FONTREG='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
FONTBOLD='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FONTALT='/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf'

def f(size,bold=False):
    p=FONTBOLD if bold else FONTREG
    return ImageFont.truetype(p,size)

def rrect(draw,xy,radius,fill,outline=None,width=2):draw.rounded_rectangle(xy,radius=radius,fill=fill,outline=outline,width=width)
def label(draw,text,xy,size=24,color=NAVY,bold=False):draw.text(xy,text,font=f(size,bold),fill=color)
def center(draw,text,y,size=26,color=NAVY,bold=False):
    font=f(size,bold); bb=draw.textbbox((0,0),text,font=font);draw.text(((W-(bb[2]-bb[0]))/2,y),text,font=font,fill=color)

def bg(k):
    top=CREAM; bottom=BG
    a=np.linspace(0,1,H)[:,None,None]
    arr=(np.array(top)[None,None,:]*(1-a)+np.array(bottom)[None,None,:]*a).astype(np.uint8)
    arr=np.repeat(arr,W,axis=1)
    im=Image.fromarray(arr); d=ImageDraw.Draw(im)
    rrect(d,(24,24,696,110),25,WHITE)
    label(d,'AI IN 60 SECONDS', (48,42),31,NAVY,True)
    label(d,'MOTION PROTOTYPE   |   NO FINAL VOICE', (50,86),15,MUTED)
    p=SCENES[k]; label(d,p[2],(46,154),30,ORANGE,True)
    # one-sentence hook/teaching statement, no dense infographic
    label(d,p[3],(46,216),27,NAVY,True)
    rrect(d,(34,310,686,1018),30,WHITE)
    rrect(d,(32,1056,688,1167),20,(238,244,249))
    label(d,p[4],(52,1072),20,NAVY,True)
    label(d,'TIMING IS PROVISIONAL • VOICEOVER PENDING',(52,1120),14,MUTED)
    label(d,'ONE IDEA   /   ONE VISUAL   /   ONE TAKEAWAY',(52,1204),15,MUTED)
    # progress track
    rrect(d,(34,1181,686,1189),4,(211,224,236))
    return cv2.cvtColor(np.asarray(im),cv2.COLOR_RGB2BGR)

BACK=[bg(i) for i in range(len(SCENES))]
def col(c):return (c[2],c[1],c[0])
def box(im,x,y,w,h,color=WHITE,r=20,edge=(214,226,236)):
    x,y,w,h=map(int,(x,y,w,h)); r=min(r,w//2,h//2)
    cv2.rectangle(im,(x+r,y),(x+w-r,y+h),col(color),-1)
    cv2.rectangle(im,(x,y+r),(x+w,y+h-r),col(color),-1)
    for cx in (x+r,x+w-r):
        for cy in (y+r,y+h-r):cv2.circle(im,(cx,cy),r,col(color),-1)
    cv2.rectangle(im,(x+r,y),(x+w-r,y+h),col(edge),1)

def txt(im,s,x,y,scale=.8,color=NAVY,th=2,centered=False):
    ft=cv2.FONT_HERSHEY_SIMPLEX;size=cv2.getTextSize(s,ft,scale,th)[0]
    if centered:x-=size[0]//2
    cv2.putText(im,s,(int(x),int(y)),ft,scale,col(color),th,cv2.LINE_AA)

def arrow(im,a,b,color=BLUE,thick=4,frac=1):
    ax,ay=a;bx,by=b;t=max(0,min(1,frac));v=(int(ax+(bx-ax)*t),int(ay+(by-ay)*t))
    cv2.line(im,(int(ax),int(ay)),v,col(color),thick,cv2.LINE_AA)
    if t>.05:
        ang=math.atan2(v[1]-ay,v[0]-ax);l=15
        for d in [-.55,.55]:cv2.line(im,v,(int(v[0]-l*math.cos(ang+d)),int(v[1]-l*math.sin(ang+d))),col(color),thick,cv2.LINE_AA)

def moving(im,start,end,phase,color=ORANGE,r=11):
    u=(phase%1);x=int(start[0]+(end[0]-start[0])*u);y=int(start[1]+(end[1]-start[1])*u)
    cv2.circle(im,(x,y),r,col(color),-1,cv2.LINE_AA)
    cv2.circle(im,(x,y),max(2,r//3),col(WHITE),-1,cv2.LINE_AA)

def node(im,x,y,title,color=BLUE,width=172):
    box(im,x-width//2,y-44,width,88,(245,249,254),15)
    cv2.circle(im,(x-width//2+24,y),9,col(color),-1)
    txt(im,title,x+8,y+8,.57,NAVY,2,True)

def draw_scene(im,k,t):
    p=t-SCENES[k][0];length=SCENES[k][1]-SCENES[k][0];u=p/length
    cv2.line(im,(34,1185),(34+int(652*t/TOTAL),1185),col(ORANGE),7,cv2.LINE_AA)
    if k==0:
        # tangible contrast: 1 quick question and long training timeline
        box(im,80,430,560,135,(237,246,254),20)
        txt(im,'YOUR QUESTION',360,484,.9,BLUE,2,True)
        txt(im,'"Is this spam?"',360,534,.85,NAVY,2,True)
        box(im,95,680,530,125,(251,245,235),20)
        txt(im,'THE MODEL LEARNED BEFORE',360,728,.71,ORANGE,2,True)
        arrow(im,(210,770),(520,770),ORANGE,4,min(1,u*1.6))
        for j in range(3):moving(im,(220,770),(515,770),u*.8+j/3,ORANGE,9)
        txt(im,'TRAINING',360,862,.83,NAVY,2,True)
    elif k==1:
        # two branches trace sequentially
        node(im,360,424,'EXAMPLES',BLUE,200)
        node(im,178,720,'TRAINING',ORANGE,230)
        node(im,536,720,'USE MODEL',GREEN,235)
        arrow(im,(345,470),(180,670),ORANGE,5,min(1,u*2.2))
        arrow(im,(375,470),(535,670),GREEN,5,max(0,min(1,(u-.45)*2.2)))
        txt(im,'LEARN PATTERNS',177,837,.66,ORANGE,2,True)
        txt(im,'MAKE OUTPUT',535,837,.66,GREEN,2,True)
        for j in range(3):moving(im,(345,470),(180,670),u*1.5+j/3,ORANGE,7)
    elif k==2:
        for i,(name,c) in enumerate([('SPAM',RED),('GENUINE',GREEN),('SPAM',RED),('GENUINE',GREEN)]):
            y=408+i*104
            box(im,65,y,185,75,(250,251,253),14)
            txt(im,name,157,y+46,.59,c,2,True)
            arrow(im,(257,y+38),(450,640),BLUE,2,.95)
            moving(im,(259,y+38),(450,640),(u*1.6+i*.22),c,9)
        node(im,548,640,'MODEL',BLUE,190)
        for i in range(4):moving(im,(465,640),(536,640),u*1.6+i*.25,BLUE,7)
        txt(im,'many examples, repeatedly',360,948,.7,MUTED,2,True)
    elif k==3:
        cv2.circle(im,(360,610),121,col((236,246,255)),-1)
        loc=[(287,555),(433,555),(285,670),(435,670),(360,610)]
        for a,b in [(0,4),(1,4),(2,4),(3,4)]:
            arrow(im,loc[a],loc[b],BLUE,3,max(0,min(1,(u*2-a*.17))))
        for i,(x,y) in enumerate(loc):
            rr=14+int(5*(math.sin(2*math.pi*(u*3+i*.3))+1)/2)
            cv2.circle(im,(x,y),rr,col(ORANGE if i==4 else BLUE),-1,cv2.LINE_AA)
        txt(im,'PARAMETERS ADJUST',360,826,.8,BLUE,2,True)
        # adaptive meter visually increases, without claiming numerical accuracy
        cv2.rectangle(im,(180,871),(540,895),col((220,233,243)),-1)
        cv2.rectangle(im,(180,871),(180+int(360*min(1,u)),895),col(GREEN),-1)
        txt(im,'not a literal brain',360,953,.65,MUTED,2,True)
    elif k==4:
        node(im,360,400,'NEW EMAIL',BLUE,250)
        node(im,360,640,'TRAINED MODEL',ORANGE,285)
        node(im,360,866,'LIKELY SPAM',RED,280)
        arrow(im,(360,449),(360,590),BLUE,5,min(1,u*2))
        arrow(im,(360,690),(360,812),RED,5,max(0,min(1,(u-.40)*2)))
        for j in range(4):moving(im,(360,448),(360,586),u*2+j/4,BLUE,7)
        if u>.55:txt(im,'PREDICTION, NOT CERTAINTY',360,985,.58,MUTED,2,True)
    elif k==5:
        node(im,360,425,'PROMPT',BLUE,200)
        node(im,360,627,'TRAINED MODEL',ORANGE,280)
        arrow(im,(360,474),(360,574),BLUE,4,min(1,u*2.5))
        outputs=[('TEXT',180,836),('IMAGE',545,836),('CODE',180,957),('MUSIC',545,957)]
        for i,(name,x,y) in enumerate(outputs):
            s=max(0,min(1,(u-.23-i*.1)*3))
            if s:
                arrow(im,(360,679),(x,y-48),GREEN,3,s)
                if s>.7:node(im,x,y,name,GREEN,185)
    elif k==6:
        node(im,360,423,'AI ANSWER',BLUE,240)
        node(im,190,713,'CLAIM',RED,210)
        node(im,530,713,'SOURCE',GREEN,215)
        arrow(im,(360,470),(190,661),RED,4,min(1,u*2.2))
        arrow(im,(360,470),(530,661),GREEN,4,max(0,min(1,(u-.18)*2)))
        txt(im,'COMPARE THE CLAIM',360,855,.77,NAVY,2,True)
        if u>.6:node(im,360,955,'VERIFY',GREEN,210)
    elif k==7:
        pts=[(360,447,'EXAMPLES',BLUE),(180,650,'TRAIN',ORANGE),(540,650,'USE',GREEN),(360,873,'CHECK',RED)]
        # This is an intentionally stylized 3D-like layered mind map, not a true 3D render
        for i,(x,y,name,c) in enumerate(pts):
            if u>i*.12:
                # double shadow gives slight floating depth
                box(im,x-107,y-37,222,82,(207,220,234),17)
                node(im,x,y,name,c,220)
        for i,(a,b) in enumerate([(0,1),(1,2),(2,3)]):
            if u>i*.16:
                x1,y1=pts[a][:2];x2,y2=pts[b][:2]
                arrow(im,(x1,y1+48),(x2,y2-48),[BLUE,ORANGE,GREEN][i],5,max(0,min(1,(u-i*.16)*2.8)))
        if u>.75:txt(im,'TRAIN FIRST. USE NEXT. CHECK.',360,996,.59,NAVY,2,True)
    # always-visible timecode and scene index
    txt(im,f'{int(t//60):02d}:{int(t%60):02d}',642,1254,.55,MUTED,1,True)
    return im

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',default='AI_training_vs_using_motion_prototype_SILENT.mp4');ap.add_argument('--seconds',type=float,default=60.0,help='Short preview: 0 < duration <= 60')
    a=ap.parse_args();assert 0<a.seconds<=60
    cmd=['ffmpeg','-hide_banner','-loglevel','error','-y','-f','rawvideo','-pixel_format','bgr24','-video_size',f'{W}x{H}','-framerate',str(FPS),'-i','-','-an','-c:v','libx264','-preset','veryfast','-crf','21','-pix_fmt','yuv420p','-movflags','+faststart',a.output]
    proc=subprocess.Popen(cmd,stdin=subprocess.PIPE)
    total=int(round(FPS*a.seconds))
    try:
        for i in range(total):
            t=i/FPS;k=next((j for j,s in enumerate(SCENES) if s[0]<=t<s[1]),len(SCENES)-1)
            frame=draw_scene(BACK[k].copy(),k,t)
            proc.stdin.write(frame.tobytes())
    finally:
        if proc.stdin:proc.stdin.close()
        rc=proc.wait()
    if rc:raise RuntimeError(f'ffmpeg failed exit={rc}')
    print(f'Wrote {a.output}; {total} frames; {a.seconds:.3f}s; {W}x{H} at {FPS} fps; SILENT PROTOTYPE')
if __name__=='__main__':main()
