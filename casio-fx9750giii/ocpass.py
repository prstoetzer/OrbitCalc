# ocpass.py - OrbitCalc PASSES for Casio fx-9750GIII (CasioPython)
# Next 10 passes over your location from AMSAT mean elements.
# Narrow output for the ~21-char console. Uses only math.
from math import *

PI2=6.283185307179586
D=pi/180.0;R=180.0/pi
MU=398600.4418;RE=6378.137;J2=1.08262668e-3

def jd(y,mo,d,h,mi,s):
 if mo<=2:y-=1;mo+=12
 a=y//100;b=2-a+a//4
 return (int(365.25*(y+4716))+int(30.6001*(mo+1))+d+b-1524.5
  +(h+mi/60.0+s/3600.0)/24.0)

def gmst(j):
 t=(j-2451545.0)/36525.0
 g=280.46061837+360.98564736629*(j-2451545.0)+0.000387933*t*t-t*t*t/3.871e7
 g=g%360.0
 return (g+360.0 if g<0 else g)*D

def kep(m,e):
 x=m
 for _ in range(40):
  dx=(x-e*sin(x)-m)/(1-e*cos(x));x-=dx
  if abs(dx)<1e-11:break
 return x

# globals set by setsat
A=N0=E0=I0=R0=P0=M0=EP=RD=PD=0.0
def setsat(inc,ecc,raan,argp,ma,mm,ep):
 global A,N0,E0,I0,R0,P0,M0,EP,RD,PD
 I0=inc*D;E0=ecc;R0=raan*D;P0=argp*D;M0=ma*D
 N0=mm*PI2/86400.0;EP=ep
 A=(MU/(N0*N0))**(1.0/3.0)
 p=A*(1-E0*E0);f=1.5*J2*(RE/p)**2*N0
 ci=cos(I0);si=sin(I0)
 RD=-f*ci;PD=f*(2.0-2.5*si*si)

def look(j,la,lo):
 dt=(j-EP)*86400.0
 m=(M0+N0*dt)%PI2;rn=R0+RD*dt;ar=P0+PD*dt
 ee=kep(m,E0)
 xo=A*(cos(ee)-E0);yo=A*sqrt(1-E0*E0)*sin(ee)
 u=atan2(yo,xo)+ar;r=sqrt(xo*xo+yo*yo)
 co=cos(rn);so=sin(rn);cu=cos(u);su=sin(u)
 ci=cos(I0);si=sin(I0)
 x=r*(co*cu-so*su*ci);y=r*(so*cu+co*su*ci);z=r*(su*si)
 g=gmst(j);cg=cos(g);sg=sin(g)
 xe=cg*x+sg*y;ye=-sg*x+cg*y;ze=z
 clat=cos(la);slat=sin(la);clon=cos(lo);slon=sin(lo)
 ox=RE*clat*clon;oy=RE*clat*slon;oz=RE*slat
 rx=xe-ox;ry=ye-oy;rz=ze-oz
 s=slat*clon*rx+slat*slon*ry-clat*rz
 e=-slon*rx+clon*ry
 zz=clat*clon*rx+clat*slon*ry+slat*rz
 rng=sqrt(rx*rx+ry*ry+rz*rz)
 el=asin(zz/rng);az=atan2(e,-s)
 if az<0:az+=PI2
 return el,az

def cal(j):
 j+=0.5;Z=int(j);F=j-Z
 if Z<2299161:a=Z
 else:al=int((Z-1867216.25)/36524.25);a=Z+1+al-al//4
 b=a+1524;c=int((b-122.1)/365.25)
 dd=int(365.25*c);e=int((b-dd)/30.6001)
 day=b-dd-int(30.6001*e)+F
 mo=e-1 if e<14 else e-13
 y=c-4716 if mo>2 else c-4715
 d=int(day);sec=(day-d)*86400.0
 h=int(sec//3600);sec-=h*3600;mi=int(sec//60);s=sec-mi*60
 return y,mo,d,h,mi,s

def grid(g):
 g=g.upper()
 lo=(ord(g[0])-65)*20-180;la=(ord(g[1])-65)*10-90
 lo+=(ord(g[2])-48)*2;la+=(ord(g[3])-48)
 if len(g)>=6:
  lo+=(ord(g[4])-65)/12.0+1/24.0;la+=(ord(g[5])-65)/24.0+1/48.0
 else:lo+=1.0;la+=0.5
 return la*D,lo*D

def passes(la,lo,j0,n=10):
 st=30.0/86400.0;j=j0;end=j0+12.0
 inp=False;npa=0;mel=-9;aa=at=al=aos=tca=0.0
 while j<end and npa<n:
  el,az=look(j,la,lo)
  if el>=0 and not inp:
   a0=j-st;a1=j
   for _ in range(22):
    m=0.5*(a0+a1);e2,z2=look(m,la,lo)
    if e2>=0:a1=m
    else:a0=m
   aos=a1;_,aa=look(aos,la,lo);inp=True;mel=-9
  if inp:
   el,az=look(j,la,lo)
   if el>mel:mel=el;tca=j
   if el<0:
    a0=j-st;a1=j
    for _ in range(22):
     m=0.5*(a0+a1);e2,z2=look(m,la,lo)
     if e2>=0:a0=m
     else:a1=m
    los=a0;_,al=look(los,la,lo)
    t0=tca-st;t1=tca+st
    for _ in range(30):
     ml=t0+(t1-t0)/3;mr=t1-(t1-t0)/3
     e1,_=look(ml,la,lo);e3,_=look(mr,la,lo)
     if e1<e3:t0=ml
     else:t1=mr
    tca=0.5*(t0+t1);mel,at=look(tca,la,lo)
    y,mo,d,h,mi,s=cal(aos)
    _,_,_,h2,mi2,s2=cal(los)
    print("%02d/%02d %02d:%02d-%02d:%02d"%(mo,d,h,mi,h2,mi2))
    print(" El%2.0f Az%3.0f/%3.0f/%3.0f"%(mel*R,aa*R,at*R,al*R))
    inp=False;npa+=1
  j+=st

def main():
 print("OrbitCalc PASSES")
 inc=float(input("INC: "));ecc=float(input("ECC: "))
 rn=float(input("RAAN: "));ar=float(input("ARGP: "))
 ma=float(input("MA: "));mm=float(input("MM: "))
 print("EPOCH UTC:")
 y=int(input("Y:"));mo=int(input("Mo:"));d=int(input("D:"))
 h=int(input("H:"));mi=int(input("Mi:"));s=float(input("S:"))
 setsat(inc,ecc,rn,ar,ma,mm,jd(y,mo,d,h,mi,s))
 print("NOW UTC:")
 ny=int(input("Y:"));nmo=int(input("Mo:"));nd=int(input("D:"))
 nh=int(input("H:"));nmi=int(input("Mi:"))
 j0=jd(ny,nmo,nd,nh,nmi,0)
 g=input("Grid? y/n: ").strip().lower()
 if g=="y":la,lo=grid(input("Grid: ").strip())
 else:
  la=float(input("Lat+N: "))*D;lo=float(input("Lon+E: "))*D
 print("dd/mm AOS-LOS")
 passes(la,lo,j0,10)

main()
