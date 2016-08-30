import sys,os,itertools,operator
import tempfile,logging,time
import codecs
logging.basicConfig(level=logging.INFO)
editor = 'vim'

executable = lambda(_): os.path.isfile(_) and os.access(_,os.X_OK)
which = lambda _,envvar="PATH",extvar='PATHEXT':_ if executable(_) else iter(filter(executable,itertools.starmap(os.path.join,itertools.product(os.environ.get(envvar,os.defpath).split(os.pathsep),(_+e for e in os.environ.get(extvar,'').split(os.pathsep)))))).next()

#hate python devers
WIN32=True if sys.platform == 'win32' else False

### globals
try:
	EDITOR = os.environ['EDITOR'] if 'EDITOR' in os.environ else which(editor)
except StopIteration:
	logging.fatal("Unable to locate editor in PATH : {!r}".format(os.environ.get('EDITOR',editor)))
	sys.exit(1)
EDITOR_ARGS = os.environ.get('EDITOR_ARGS', '-O2' if editor in EDITOR else '')
ENCODING = 'utf-8-sig'

### code
def help(argv0):
	print 'Usage: {:s} [-d] paths...'.format(argv0)
	return

def rename_file(a,b):
	try:
		parentdir = os.path.normpath(os.path.join(b, os.path.pardir)) if os.path.isdir(a) else os.path.dirname(b)
		if not os.path.isdir(parentdir):
			logging.info("creating base directory {!r} to contain {!r}".format(parentdir,b))
			os.makedirs(parentdir)
	except Exception, e:
		logging.warning("os.makedirs({!r}) raised {!r}".format(a,b,e))
		return False

	try:
		result = os.rename(a,b)
	except Exception, e:
		logging.warning("os.rename({!r},{!r}) raised {!r}".format(a,b,e))
		return False
	logging.info("renamed {!r} to {!r}".format(a,b))
	return True

def rename(source,target):
	count = 0
	for a,b in zip(source,target):
		if a != b:
			count += int(rename_file(a,b))
		continue
	return count

def listing(p):
	for dirpath,_,filenames in os.walk(os.path.relpath(p)):
		for name in sorted(filenames):
			yield os.path.join(dirpath,name)
		continue
	return

def dirlisting(p):
	for dirpath,dirnames,_ in os.walk(os.path.relpath(p)):
		for name in sorted(dirnames):
			yield os.path.join(dirpath,name)
	return

def edit(list):
	list = map(None, list)

	[ logging.debug("renamer.edit(...) - found file {:d} -- {!r}".format(i,s)) for i,s in enumerate(list) ]

	#hate python devers
	with tempfile.NamedTemporaryFile(prefix='renamer.',suffix='.source', delete=not WIN32) as t1,tempfile.NamedTemporaryFile(prefix='renamer.',suffix='.destination', delete=not WIN32) as t2:
		# really hate python devers
		map(operator.methodcaller('close'), (t1,t2))
		with codecs.open(t1.name, 'w+b', encoding=ENCODING) as t1e, codecs.open(t2.name, 'w+b', encoding=ENCODING) as t2e:
			map(operator.methodcaller('writelines',[_+'\n' for _ in list]), (t1e,t2e))
			map(operator.methodcaller('flush'), (t1e,t2e))

		logging.info("renamer.edit(...) - using source filename {!r}".format(t1.name))
		logging.info("renamer.edit(...) - using destination filename {!r}".format(t2.name))

		message = "os.spawnv(os.P_WAIT, {!r}, [{!r}, {!r}, '--', {!r}, {!r}])".format(EDITOR, EDITOR, EDITOR_ARGS, t1.name, t2.name)
		try:
			result = os.spawnv(os.P_WAIT, EDITOR, [EDITOR, EDITOR_ARGS, '--', t1.name, t2.name])
		except Exception, e:
			logging.fatal("{:s} raised {!r}".format(message, e))
			raise
		else:
			if result != 0: logging.warning("{:s} returned {:d}".format(message, result))

		#really hate python devers
		with codecs.open(t1.name, 'rb', encoding=ENCODING) as t1e, codecs.open(t2.name, 'rb', encoding=ENCODING) as t2e:
			map(operator.methodcaller('seek', 0), (t1e,t2e))
			source = map(unicode.strip, t1e.readlines())
			destination = map(unicode.strip, t2e.readlines())

		# restore the handles so that when we exit 'with', it won't double-close them.
		t1,t2 = map(open, (t1.name,t2.name))

	#if len([None for x,y in zip(source,list) if x != y]) > 0:
	if any(x != y for x,y in zip(source,list)):
		logging.warning("renamer.edit(...) - source list was modified. ignoring.")

	if len(destination) != len(list):
		logging.fatal("renamer.edit(...) - destination list contains a different number of entries from the source. terminating. ({:d} != {:d})".format(len(destination), len(list)))
		return []

	return source,destination

def main_files(*paths):
	source = []
	for p in paths:
		source.extend(listing(p))

	if len(source) == 0:
		logging.info("renamer.main(...) - found no files. terminating.")
		return

	logging.info("renamer.main(...) - found {:d} files. spawning editor..".format(len(source)))
	time.sleep(1)

	_, target = edit(source)
	# FIXME: compare newsource and target to see what's attempting to be renamed
	#if len([None for x,y in zip(source,list) if x != y]) > 0:
#	if any(x != y for x,y in zip(source,list)):
#		logging.warning("renamer.edit(...) - source list was modified. ignoring.")

#	if len(destination) != len(list):
#		logging.fatal("renamer.edit(...) - destination list contains a different number of entries from the source. terminating. ({:d} != {:d})".format(len(destination), len(list)))
#		return []

	count = rename(source,target)
	logging.info("renamer.main(...) - renamed {:d} files.".format(count))
	return

def main_directories(*paths):
	source = []
	for p in paths:
		source.extend(dirlisting(p))

	if len(source) == 0:
		logging.warning("renamer.main(...) - found no directories. terminating.")
		return

	logging.info("renamer.main(...) - found {:d} directories. spawning editor..".format(len(source)))
	time.sleep(2)

	_, target = edit(source)
	# FIXME: compare newsource and target to see what's attempting to be renamed
	#if len([None for x,y in zip(source,list) if x != y]) > 0:
#	if any(x != y for x,y in zip(source,list)):
#		logging.warning("renamer.edit(...) - source list was modified. ignoring.")

#	if len(destination) != len(list):
#		logging.fatal("renamer.edit(...) - destination list contains a different number of entries from the source. terminating. ({:d} != {:d})".format(len(destination), len(list)))
#		return []

	count = rename(source,target)
	logging.info("renamer.main(...) - renamed {:d} directories.".format(count))
	return

def parse_commandline(arguments):
	options,arguments = [],[x for x in arguments]
	if '--' in arguments:
		_ = argv.index('--')
		options,arguments = arguments[:_],arguments[_+1:]
	elif '-d' in arguments:
		options = ['-d']
		del(arguments[arguments.index('-d')])
	return options,arguments

if __name__ == '__main__':
	import sys

	try:
		argv0,argv = sys.argv[0],sys.argv[1:]
	except:
		argv0,argv = sys.argv[0],[]

	options,arguments = parse_commandline(argv)

	if len(arguments) < 1:
		help(argv0)
		sys.exit(1)

	main = main_files
	if '-d' in options:
		main = main_directories
	result = main(*map(unicode,arguments))
	sys.exit(int(result is not None))
