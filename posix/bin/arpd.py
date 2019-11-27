#!/usr/bin/env python2
###
###
### TODO:
###         figure out how to trick a switch into giving this box all traffic
###         clean up info messages so they're more easily parseable
###         send    whatmac whatip  -   whosent theirip
###         test test test test test test test test
###
###
import sys,socket,signal
import pcap
DEFAULT_CONFIG_FILE = ''
sys.path.append('/usr/local/bin')
from scapy import *

conf.verb = 0
## our configuration
arpd_conf = {
#    'interface' : 'hme0',
    'snaplen' : 60,     # length of Ether/Arp
    'timeout' : 100,
    'rearp_count' : 2,
    'ethers_file' : 'arpd.ethers',
    'verbose' : 3
}

######### identification of interfaces
def get_interface_by_idx(e, faces):
    e = int(e)
    a = [ f for i, f in zip(range(len(faces)), faces) if e == i ]
    return a[0]

def get_interface_by_name(e, faces):
    e = str(e)
    a = [ f for f in faces if e == f[0] ]
    return a[0]

def get_interface_by_address(e, faces):
    str(e)
    for f in faces:
        for addr in f[2]:
            if addr[0] == e:
                return f

    # just to be consistent
    return [][0]

def get_interface(e):
    '''gets an interface by something'''
    faces = pcap.findalldevs()

    cryztal = [
        get_interface_by_idx,
        get_interface_by_name,
        get_interface_by_address
    ]

    for meth in cryztal:
        try:
            return meth(e, faces)
        except:
            pass

    return None

class arp_enforce(object):
    '''class that does all the arp enforcement work'''
    ## database of IP/MAC pairs
    ethers = {}

    ## arp packets that we send out
    # key is (who to arp, what ip they want)
    # value (who sent arp, what ip sent the request, count of packets)
    queue = {}

    def __init__(self, snaplen=60, timeout=100, promisc=1, packetcount=5, verbose=1):
        pc = pcap.pcapObject()
        pc.open_live(conf.iface, snaplen, promisc, timeout)
        pc.setfilter('arp', 0, 0)
        pc.setnonblock(1)

        self.L2 = conf.L2socket(iface=conf.iface)

        self.timeout = timeout
        self.pc = pc
        self.packetcount=packetcount
        self.verbose = verbose

    def _wait_for_read(self):
        ''' wait until we have a packet to read '''
        if sys.platform == 'win32':
            raise NotImplementedError('select not on win32')
            return None

        (r, w, e) = select([self.pc.fileno()], [], [], self.timeout)
        return r

    def info(self, v, level=1):
        if level <= self.verbose:
            print v

    def idle(self):
        ''' our idle loop where everything starts'''
        x = self._wait_for_read()
        if x:
            self.pc.dispatch(1, self.handle_packet)
        self.rearp()

    def handle_packet(self, len, data, timestamp):
        ''' main packet handler '''
        pkt = Ether(data)

        eth = pkt.getlayer(Ether)
        arp = pkt.getlayer(ARP)

        # is-at for windoze
        if eth.dst != 'ff:ff:ff:ff:ff:ff':
            self.do_checkreply(pkt, timestamp)

        # who-has for windoze
        if eth.dst == 'ff:ff:ff:ff:ff:ff':
            self.do_checkrequest(pkt, timestamp)

    def do_checkreply(self, pkt, timestamp):
        ''' is-at - someone is hijacking arp '''
        eth = pkt.getlayer(Ether)
        arp = pkt.getlayer(ARP)

        ## sanity checks
        if eth.src != arp.hwsrc:
            self.info(".eth['%s'] != arp['%s']"%(eth.src, arp.hwsrc), 3)

        ## assignments
        whatmac = arp.hwsrc
        whatip = arp.pdst

        sendermac = arp.hwdst   # should be 00:00:00:00:00:00
        senderip = arp.psrc

        i = (whatmac, whatip)
        if (i not in self.queue) and (whatip in self.ethers) and self.ethers[whatip] != eth.dst:
            self.info('[%d] %s is telling %s that its ip is %s'%(timestamp, eth.dst, whatmac, whatip), 1)
            self.queue[i] = ( timestamp, sendermac, senderip, self.packetcount )
            ## XXX: might want to punish 'sendermac'

    def do_checkrequest(self, pkt, timestamp):
        ''' who-has - answer any requests '''
        eth = pkt.getlayer(Ether)
        arp = pkt.getlayer(ARP)

        ## sanity checks
        if eth.src != arp.hwsrc:
            self.info(".eth['%s'] != arp['%s']"%(eth.src, arp.hwsrc), 2)

        if eth.dst not in ['ff:ff:ff:ff:ff:ff', '00:00:00:00:00:00']:
            self.info(".eth['dst'] != broadcast - %s"% eth.dst, 2)

        ## assignments
        whatmac = arp.hwsrc
        whatip = arp.pdst

        sendermac = arp.hwdst # this should be 00:00:00:00:00:00
        senderip = arp.psrc

        i = (whatmac, whatip)
        if (i not in self.queue) and (whatip in self.ethers):
            self.info('[%d] %s (%s) is asking for %s'%(timestamp, eth.src, senderip, whatip), 1)
            self.queue[i] = ( timestamp, sendermac, senderip, self.packetcount )

    def rearp(self):
        ''' does the actual rearpping of everything in our queue '''
        l = {}
        for i in self.queue:

            ## re-arp 'whom' for the ip 'whatip' with 'mac'
            (whom, whatip) = i
            (ts, sender_mac, sender_ip, count) = self.queue[i]

            mac = self.ethers[whatip]

            # make sure that we aren't correcting ourself
            if sender_mac == mac:
                continue

            # check if our count is ok
            if (count > 0):
                # send out packet
                eth = Ether(dst=whom, src=mac)
                arp = ARP(op='is-at', hwsrc=mac, hwdst=whom, psrc=whatip, pdst=sender_ip)
                self.info('[%d] arping %s with %s = %s [%d packets left]'%(ts, whom, whatip, mac, count))

                s = eth/arp
                self.L2.send( str(s) )

                l[i] = (ts, sender_mac, sender_ip, count - 1)

        self.queue = l


class lexer:
    '''just implements a tokenizer'''
    skip = ' \t\n'
    tokens = []

    def lex(self, s):
        if not s:
            return

        s = iter(s)

        res = ''
        t = self.tokens
        try:
            while True:
                ch = s.next()

                if ch in self.skip:
                    if not res:
                        continue

                    if len(t) > 1:
                        raise ValueError("too many results for token '%s'"% res)

                    # return current result
                    if len(t) == 1:
                        k,v = t[0]
                        yield (k, res)
                        res = ''
                        t = self.tokens

                    continue

                if len(t) > 1:
                    t = [ (k,v) for k,v in t if ch in v ]
                    if not t:
                        raise ValueError("unexpected character '%c'"%ch)

                elif len(t) == 1:
                    k,v = t[0]

                    if ch not in v:
                        raise ValueError("unexpected character '%c' for token %s"%(ch,repr(t[0])) )

                res += ch

        except StopIteration:
            if ch not in self.skip:
                t = [ (k,v) for k,v in t if ch in v ]
                if len(t) == 1:
                    k,v = t[0]
                    yield (k, res)
                elif len(t) > 1:
                    raise ValueError("too many results for token '%s'"% res)
                else:
                    raise ValueError("unexpected character '%c'"%ch)

class ether_parse(lexer):
    ''' parses /etc/ethers file '''
    # character sets
    char_alpha = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
    char_digit = '0123456789'
    char_hex_10_15 = 'abcdefABCDEF'
    char_hex = char_digit + char_hex_10_15

    # lexer properties
    skip = ' \t'
    tokens = [
        ( 'hostname', char_digit+char_alpha+'.-_' ),
        ( 'hwaddr', char_hex+':' )
    ]

    def __init__(self, data):
        self.data = ''.join( list(data) )

    def parse(self):
        l = []
        for e in self._parse(self.data):
            k = v = None
            for n in e:
                if n[0] == 'hostname':
                    v = n[1]
                if n[0] == 'hwaddr':
                    k = n[1]

            l.append( (k,v) )

        self.elements = l

    def resolve(self):
        l = []
        for k,v in self.elements:
            try:
                l.append( (k, socket.gethostbyname(v)) )
            except socket.gaierror,(err, msg):
                if err == 8:
                    raise ValueError("unable to resolve host '%s'"% v)
                raise

        self.elements = l

    def _parse(self, data):
        n = 0
        l = []
        for s in data.split('\n'):
            n += 1
            # remote comment
            try:
                s = s[ : s.index('#') ]
            except ValueError:
                pass

            if not s:
                continue

            if s[0] == '+':
                raise NotImplementedError('NIS not implemented')

            try:
                r = self.lex(s)
                tokens = list(r)
            except ValueError, (msg):
                raise ValueError(msg, n, s)

            if not tokens:
                continue

            t = [ k for k,v in tokens ]
            if t:
                t = ' '.join(t)
            else:
                t = 'empty'

            if (len(tokens) != 2):
                raise ValueError('expected "hwaddr hostname"\ngot "%s"'%t, n, s)

            if not (tokens[0][0] == 'hwaddr' and tokens[1][0] == 'hostname'):
                raise ValueError('expected "hwaddr hostname"\ngot "%s"'%t, n, s)

            l.append(tokens)

        return l

    def __getitem__(self, i):
        for k,v in self.elements:
            if k == i:
                return v
        raise KeyError(i)

    def keys(self):
        return [ k for k,v in self.elements ]

    def values(self):
        return [ v for k,v in self.elements ]

    def __iter__(self):
        for k,v in self.elements:
            yield k

    def __contains__(self, k):
        return k in [ k for k,v in self.elements ]

    def items(self):
        return self.elements

    def has_key(self, k):
        return k in self

    def __repr__(self):
        return repr( dict([(k,v) for k,v in self.elements]) )

###################
class main:
    '''main class'''
    def __init__(self, conf):
        self.conf = conf

        blah = {
            'snaplen' : conf['snaplen'],
            'timeout' : conf['timeout'],
            'packetcount' : conf['rearp_count'],
            'verbose' : conf['verbose']
        }

        self.arp = arp_enforce(promisc=1, **blah)
        signal.signal(signal.SIGHUP, self.sighup)

    def read_ethers(self):
        ethers = self._get_ethers(self.conf['ethers_file'])

        print '[arp table]'
        for k in ethers:
            print '<%s> %s'% (k, ethers[k])
        print '-'*7

        self.arp.ethers = ethers

    def _get_ethers(self, filename):
        f = file(filename)
        e = ether_parse( ''.join(list(f)) )
        e.parse()

        print 'resolving hosts..'
        e.resolve()

        return dict( [(v,k) for k,v in e.items()] )

    def sighup(self, signum, frame):
        print "rereading '%s'"% self.conf['ethers_file']
        self.read_ethers()

    def run(self):
        while True:
            self.arp.idle()

if __name__ == '__main__':
    conf.iface = 'hme0'

    _ = main(arpd_conf)
    print 'reading %s'% arpd_conf['ethers_file']
    _.read_ethers()
    _.run()
