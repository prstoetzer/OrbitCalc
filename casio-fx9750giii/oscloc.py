# oscloc.py - OSCARLOCATOR for Casio fx-9750GIII (CasioPython)
# EQX crossings for one UTC day from one EQX + period + advance.
# Narrow output. No imports needed.

def wrap(x):
 while x>180.0:x-=360.0
 while x<=-180.0:x+=360.0
 return x

def flon(x):
 x=wrap(x)
 return ("%6.1fE"%x) if x>=0 else ("%6.1fW"%(-x))

def plon(s):
 s=s.strip().upper();sg=1.0
 if s.endswith("W"):sg=-1.0;s=s[:-1]
 elif s.endswith("E"):s=s[:-1]
 return sg*float(s.strip())

def main():
 print("OSCARLOCATOR")
 lo0=plon(input("EQX lon(eg 111.5W): "))
 nt=input("Node A/D: ").strip().upper()
 mo=int(input("Month: "));d=int(input("Day: "))
 h=int(input("EQX H: "));mi=int(input("EQX Mi: "))
 per=float(input("Period min: "))
 adv=float(input("Adv deg W: "))
 nd="ASC" if nt=="A" else "DESC"
 t0=h*60.0+mi
 k=int(t0//per)
 t=t0-k*per;lo=wrap(lo0+k*adv)
 print("%02d/%02d %s"%(mo,d,nd))
 print("orb UTC   lon")
 n=0
 while t<1440.0:
  hh=int(t//60);mm=int(t-hh*60)
  print("%2d %02d:%02d %s"%(n,hh,mm,flon(lo)))
  t+=per;lo=wrap(lo-adv);n+=1

main()
