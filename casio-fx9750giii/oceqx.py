# oceqx.py - OrbitCalc EQX for Casio fx-9750GIII (CasioPython)
# 10-day reference-orbit table: first ascending-node EQX per UTC day
# (descending node if your latitude is south). Narrow output. math only.
from math import *

PI2=6.283185307179586
D=pi/180.0
R=180.0/pi
MU=398600.4418
RE=6378.137
J2=0.00108262668

def jd(y,mo,d,h,mi,s):
 if mo<=2:
  y-=1
  mo+=12
 a=y//100
 b=2-a+a//4
 return (int(365.25*(y+4716))+int(30.6001*(mo+1))+d+b-1524.5
  +(h+mi/60.0+s/3600.0)/24.0)

def gmst(j):
 t=(j-2451545.0)/36525.0
 g=280.46061837+360.98564736629*(j-2451545.0)+0.000387933*t*t-t*t*t/38710000.0
 g=g%360.0
 return (g+360.0 if g<0 else g)*D

def kep(m,e):
 x=m
 for _ in range(40):
  dx=(x-e*sin(x)-m)/(1-e*cos(x))
  x-=dx
  if abs(dx)<0.00000000001:break
 return x

A=N0=E0=I0=R0=P0=M0=EP=RD=PD=0.0
def setsat(inc,ecc,raan,argp,ma,mm,ep):
 global A,N0,E0,I0,R0,P0,M0,EP,RD,PD
 I0=inc*D
 E0=ecc
 R0=raan*D
 P0=argp*D
 M0=ma*D
 N0=mm*PI2/86400.0
 EP=ep
 A=(MU/(N0*N0))**(1.0/3.0)
 p=A*(1-E0*E0)
 f=1.5*J2*(RE/p)**2*N0
 ci=cos(I0)
 si=sin(I0)
 RD=-f*ci
 PD=f*(2.0-2.5*si*si)

def sub(j):
 dt=(j-EP)*86400.0
 m=(M0+N0*dt)%PI2
 rn=R0+RD*dt
 ar=P0+PD*dt
 ee=kep(m,E0)
 xo=A*(cos(ee)-E0)
 yo=A*sqrt(1-E0*E0)*sin(ee)
 u=atan2(yo,xo)+ar
 r=sqrt(xo*xo+yo*yo)
 co=cos(rn)
 so=sin(rn)
 cu=cos(u)
 su=sin(u)
 ci=cos(I0)
 si=sin(I0)
 x=r*(co*cu-so*su*ci)
 y=r*(so*cu+co*su*ci)
 z=r*(su*si)
 g=gmst(j)
 cg=cos(g)
 sg=sin(g)
 xe=cg*x+sg*y
 ye=-sg*x+cg*y
 lat=atan2(z,sqrt(xe*xe+ye*ye))
 lon=atan2(ye,xe)
 return lat,lon

def cal(j):
 j+=0.5
 Z=int(j)
 F=j-Z
 if Z<2299161:
  a=Z
 else:
  al=int((Z-1867216.25)/36524.25)
  a=Z+1+al-al//4
 b=a+1524
 c=int((b-122.1)/365.25)
 dd=int(365.25*c)
 e=int((b-dd)/30.6001)
 day=b-dd-int(30.6001*e)+F
 mo=e-1 if e<14 else e-13
 y=c-4716 if mo>2 else c-4715
 d=int(day)
 sec=(day-d)*86400.0
 h=int(sec//3600)
 sec-=h*3600
 mi=int(sec//60)
 s=sec-mi*60
 return y,mo,d,h,mi,s

def flon(x):
 return ("%6.1fE"%x) if x>=0 else ("%6.1fW"%(-x))

def eqx(ds,asc):
 st=60.0/86400.0
 j=ds
 end=ds+1.0
 pl=None
 while j<end:
  la,lo=sub(j)
  if pl is not None:
   cr=(pl<0<=la) if asc else (pl>0>=la)
   if cr:
    a0=j-st
    a1=j
    for _ in range(34):
     m=0.5*(a0+a1)
     l2,o2=sub(m)
     if (l2>=0)==asc:a1=m
     else:a0=m
    m=0.5*(a0+a1)
    l2,o2=sub(m)
    return m,o2
  pl=la
  j+=st
 return None,None

def reforb(j0,south,days=10):
 asc=not south
 y,mo,d,h,mi,s=cal(j0)
 d0=jd(y,mo,d,0,0,0)
 for k in range(days):
  j,lo=eqx(d0+k,asc)
  if j is not None:
   yy,mm,dd,hh,mi2,ss=cal(j)
   print("%02d/%02d %02d:%02d %s"%(mm,dd,hh,mi2,flon(lo*R)))

def main():
 print("OrbitCalc EQX")
 inc=float(input("INC: "))
 ecc=float(input("ECC: "))
 rn=float(input("RAAN: "))
 ar=float(input("ARGP: "))
 ma=float(input("MA: "))
 mm=float(input("MM: "))
 print("EPOCH UTC:")
 y=int(input("Y:"))
 mo=int(input("Mo:"))
 d=int(input("D:"))
 h=int(input("H:"))
 mi=int(input("Mi:"))
 s=float(input("S:"))
 setsat(inc,ecc,rn,ar,ma,mm,jd(y,mo,d,h,mi,s))
 print("NOW UTC:")
 ny=int(input("Y:"))
 nmo=int(input("Mo:"))
 nd=int(input("D:"))
 j0=jd(ny,nmo,nd,0,0,0)
 la=float(input("Lat (+N/-S): "))
 south=la<0
 print("ASC" if not south else "DESC","node EQX")
 print("dd/mm UTC  lon")
 reforb(j0,south,10)

main()
