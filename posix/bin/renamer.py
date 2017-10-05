import sys,os
import functools,operator,itertools
import argparse,tempfile,logging,time
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
FILEENCODING = 'utf-8-sig'

### code
def parse_args():
	res = argparse.ArgumentParser(description='Rename any number of files within a list of paths using an editor.', add_help=True)
	res.add_argument('-d', dest='use_dirs', action='store_true', default=False, help='rename directories instead of files')
	res.add_argument(dest='paths', metavar='path', nargs='*', action='store', type=unicode)
	return res.parse_args()

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
	for dirpath,_,filenames in os.walk(unicode(os.path.relpath(p), encoding=sys.getfilesystemencoding())):
		for name in sorted(filenames):
			yield os.path.join(dirpath,name)
		continue
	return

def dirlisting(p):
	for dirpath,dirnames,_ in os.walk(unicode(os.path.relpath(p), encoding=sys.getfilesystemencoding())):
		for name in sorted(dirnames):
			yield os.path.join(dirpath,name)
	return

def edit(list):
	list = filter(None, list)

	[ logging.debug("renamer.edit(...) - found file {:d} -- {!r}".format(i,s)) for i,s in enumerate(list) ]

	#hate python devers
	with tempfile.NamedTemporaryFile(prefix='renamer.',suffix='.source', delete=not WIN32) as t1,tempfile.NamedTemporaryFile(prefix='renamer.',suffix='.destination', delete=not WIN32) as t2:
		# really hate python devers
		map(operator.methodcaller('close'), (t1,t2))
		with codecs.open(t1.name, 'w+b', encoding=FILEENCODING) as t1e, codecs.open(t2.name, 'w+b', encoding=FILEENCODING) as t2e:
			map(operator.methodcaller('writelines', map(u'{:s}\n'.format, list)), (t1e,t2e))
			map(operator.methodcaller('flush'), (t1e,t2e))

		logging.info("renamer.edit(...) - using source filename {!r}".format(t1.name))
		logging.info("renamer.edit(...) - using destination filename {!r}".format(t2.name))

		message = "os.spawnv(os.P_WAIT, {!r}, [{!r}, {!r}, '--', {!r}, {!r}])".format(EDITOR, EDITOR, EDITOR_ARGS, t1.name, t2.name)
		try:
			result = os.spawnv(os.P_WAIT, EDITOR, [EDITOR, EDITOR_ARGS, '--', t1.name, t2.name])
		except Exception, e:
			logging.fatal("{:s} raised {!r}".format(message, e), exc_info=True)
			raise
		else:
			if result != 0: logging.warning("{:s} returned {:d}".format(message, result))

		#really hate python devers
		with codecs.open(t1.name, 'rb', encoding=FILEENCODING) as t1e, codecs.open(t2.name, 'rb', encoding=FILEENCODING) as t2e:
			map(operator.methodcaller('seek', 0), (t1e,t2e))
			source, destination = t1e.readlines(), t2e.readlines()
			source, destination = map(unicode.strip, source), map(unicode.strip, destination)

		# restore the handles so that when we exit 'with', it won't double-close them.
		t1,t2 = map(open, (t1.name,t2.name))

	#if len([None for x,y in zip(source,list) if x != y]) > 0:
	if any(x != y for x,y in zip(source,list)):
		logging.warning("renamer.edit(...) - source list was modified. using it to rename files.")
	else:
		source = list[:]

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
		return 0

	logging.info("renamer.main(...) - found {:d} files. spawning editor..".format(len(source)))
	time.sleep(1)

	newsource, target = edit(source)
	# FIXME: compare newsource and target to see what's attempting to be renamed
	#if len([None for x,y in zip(source,list) if x != y]) > 0:
#	if any(x != y for x,y in zip(source,list)):
#		logging.warning("renamer.edit(...) - source list was modified. ignoring.")

#	if len(destination) != len(list):
#		logging.fatal("renamer.edit(...) - destination list contains a different number of entries from the source. terminating. ({:d} != {:d})".format(len(destination), len(list)))
#		return []

	count = rename(newsource,target)
	logging.info("renamer.main(...) - renamed {:d} files.".format(count))
	return count

def main_directories(*paths):
	source = []
	for p in paths:
		source.extend(dirlisting(p))

	if len(source) == 0:
		logging.warning("renamer.main(...) - found no directories. terminating.")
		return 0

	logging.info("renamer.main(...) - found {:d} directories. spawning editor..".format(len(source)))
	time.sleep(2)

	newsource, target = edit(source)

	# FIXME: compare newsource and target to see what's attempting to be renamed
	#if len([None for x,y in zip(source,list) if x != y]) > 0:
#	if any(x != y for x,y in zip(source,list)):
#		logging.warning("renamer.edit(...) - source list was modified. ignoring.")

#	if len(destination) != len(list):
#		logging.fatal("renamer.edit(...) - destination list contains a different number of entries from the source. terminating. ({:d} != {:d})".format(len(destination), len(list)))
#		return []

	count = rename(newsource,target)
	logging.info("renamer.main(...) - renamed {:d} directories.".format(count))
	return count

def parse_commandline(arguments):
	options,arguments = [],[x for x in arguments]
	if '--' in arguments:
		_ = argv.index('--')
		options,arguments = arguments[:_],arguments[_+1:]
	if '-d' in arguments:
		options += ['-d']
		del(arguments[arguments.index('-d')])
	if any(opt in arguments for opt in {'-h','--help'}):
		options
	return options,arguments

if __name__ == '__main__':
	import sys
	arguments = parse_args()
	main = main_directories if arguments.use_dirs else main_files
	result = main(*arguments.paths)
	sys.exit(int(result <= 0))
