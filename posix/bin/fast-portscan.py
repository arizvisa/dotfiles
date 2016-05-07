import pickle, random

host='thunkers.net'
host = socket.gethostbyname(host)

def hash(x):
  return x * 0x100 ^ 0xc0c0c0c0

packets={}
for x in IP(dst=host)/TCP(flags='S', dport=range(0,2048)):
 seq = hash(x.getlayer(TCP).dport)
 x.getlayer(TCP).seq = seq
 x.getlayer(TCP).sport = 1024+x.getlayer(TCP).dport
 packets[seq] = x

x = file('blah2', 'wb')
x.write(host+"\n")
x.write( pickle.dumps(packets) )
x.close()

# pause while we read our config

send([ IP(dst=host)/n for n in packets.values() ])

########
import pickle
x = file('blah2', 'rb')
host=x.readline()[:-1]
packets = pickle.loads(x.read())
x.close()

def pr(x):
 print x.getlayer(TCP).sport

def fn(x):
 if isinstance(x, Packet):
  if x.haslayer(TCP):
   tcp = x.getlayer(TCP)
   l = [(x+1)&0xffffffff for x in packets.keys()]
   if tcp.ack in l:
    return True
# might want to listen for more types of error traffic
#  if x.haslayer(IP):
#   ip = x.getlayer(IP)
#   if ip.src == host:
#    return True

  return False

res = sniff(count=len(packets.values()), lfilter=fn, prn=pr)


encode the lost highway soundtrack
