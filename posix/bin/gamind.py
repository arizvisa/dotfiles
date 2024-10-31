#!/usr/bin/env python
import sys, os, signal, select
import re
import gamin

####
def dirtree(self, rootdir):
    return [ path for path,dirs,files in os.walk(rootdir) ]

class filemonitor(object):
    _monitor = None
    _poller = None
    _directories = None
    events = None

    def __init__(self):
        self._monitor = gamin.WatchMonitor()
        self._poller = select.poll()
        self.events = []
        super(filemonitor, self).__init__()

    def __monitor(self):
        def bah(path, event):
            if self.monitor(path, event):
                self.events.append(path)
        return bah

    def monitor(self, path, event):
        raise NotImplementedError

    def watch(self, path):
        if self._directories:
            raise UserError('already watching %d directories'% len(self._directories))

        self._directories = dirtree(self, path)
        for n in self._directories:
            self._monitor.watch_directory( n, self.__monitor() )

        self._poller.register( self._monitor.get_fd(), select.POLLIN)

    def unwatch(self):
        for n in self._directories:
            self._monitor.stop_watch( n )
        self._directories = None
        self._poller.unregister(self._monitor.get_fd())

    def __iter__(self):
        mon = self._monitor
        while True:
            res = self._poller.poll()
            if (mon.get_fd(), select.POLLIN) in res:
                mon.handle_events()

            yield self.events
            self.events = []

class filechangemonitor(filemonitor):
    def monitor(self, path, event):
        if event == gamin.GAMChanged:
            return True
        return False

def any(iterable, function):
    for n in iterable:
        if function(n):
            return True
    return False

def help():
    print('%s command path regexes...'% (sys.argv[0] if sys.argv[0] else __FILE__))
    sys.exit(0)

if __name__ == '__main__':
    try:
        command = sys.argv[1]
        path = sys.argv[2]
        matches = [ re.compile(n) for n in sys.argv[3:] ]
    except:
        help()

    def sigterm(signum, frame):
        mon.unwatch()
        sys.exit(0)

    signal.signal( signal.SIGTERM, sigterm )

    mon = filechangemonitor()
    mon.watch(path)

    re_match = lambda s: any( matches, lambda x: x.match(s) )

    for files in mon:
        if any( files, lambda x: re_match(x) ):
            map(os.system, (command.format(f, path=f) for f in files if re_match(f)))

