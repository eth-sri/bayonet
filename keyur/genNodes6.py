import sys

n = int(sys.argv[1])
assert(n>0)

def printLink(n1,p1,n2,p2,comma=True):
  commaStr = "," if comma else ""
  print("    (",n1,",pt",p1,") <-> (",n2,",pt",p2,")",commaStr,sep="")

print("num_steps",(n+1)*18,";")

print("topology {\n  nodes { H0, H1", end="")
for i in range(n*4):
  print(", S"+str(i), end="")
print(" }\n  links {")
printLink("H0",1,"S0",1)
print()
for i in range(n):
  if i>0:
    printLink("S"+str(4*i-1),3,"S"+str(4*i+0),1)
    print()
  printLink("S"+str(4*i+0),2,"S"+str(4*i+1),1)
  printLink("S"+str(4*i+0),3,"S"+str(4*i+2),1)
  printLink("S"+str(4*i+0),4,"S"+str(4*i+3),4)
  printLink("S"+str(4*i+1),2,"S"+str(4*i+3),1)
  printLink("S"+str(4*i+2),2,"S"+str(4*i+3),2)
  print()
printLink("S"+str(4*n-1),3,"H1",1,False)
print("  }\n}\nprograms { H0 -> h0, H1 -> h1",end="")
for i in range(n):
  print(", S",i*4," -> s0, S",i*4+1," -> s1, S",i*4+2," -> s2, S",i*4+3," -> s3",sep="",end="")
print(" }")
