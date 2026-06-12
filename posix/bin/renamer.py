#!/usr/bin/env python
import sys, os
import functools, itertools, types, builtins, operator, six
import argparse, tempfile, logging, time, shlex
import codecs

executable = lambda _: os.path.isfile(_) and os.access(_, os.X_OK)
which = lambda _, envvar="PATH", extvar='PATHEXT': _ if executable(_) else six.next(iter(filter(executable, itertools.starmap(os.path.join, itertools.product(os.environ.get(envvar, os.defpath).split(os.pathsep), (_ + e for e in os.environ.get(extvar, '').split(os.pathsep)))))))

#hate python devers
WIN32=True if sys.platform == 'win32' else False

### globals
EDITOR = 'vim'
FILEENCODING = 'utf-8-sig'

## fuck python3
def __ensure_text__(s, encoding='utf-8', errors='strict'):
    '''ripped from six v1.12.0'''
    if isinstance(s, six.binary_type):
        return s.decode(encoding, errors)
    elif isinstance(s, six.text_type):
        return s
    raise TypeError("not expecting type '%s'"% type(s))

### code
def smap(f, iterable):
	iterable = map(f, iterable)
	return [item for item in iterable]

def sfilter(f, iterable):
	iterable = filter(f, iterable)
	return [item for item in iterable]

def szip(*iterables):
	iterable = zip(*iterables)
	return [item for item in iterable]

def quote(string):
	res = string.encode('unicode-escape')
	res = res.replace(b'"', b'\\"')
	return u"\"{!s}\"".format(res.decode(sys.getfilesystemencoding()))

def parse_args():
	res = argparse.ArgumentParser(description='Rename any number of files within a list of paths using an editor.', add_help=True)
	res.add_argument('-d', dest='use_dirs', action='store_true', default=False, help='rename directories instead of files')
	res.add_argument('-n', '--dry-run', dest='dry_run', action='store_true', default=False, help='perform a dry run and only print the changes')
	res.add_argument('-v', '--verbose', dest='verbose', action='store_true', default=False, help='log the details of each action to stderr')
	res.add_argument(dest='paths', metavar='path', nargs='*', action='store', type=__ensure_text__)

	name, ext = os.path.splitext(os.path.basename(sys.argv[0] if sys.argv else __file__))
	return name, res.parse_args()

def setup(arg0, level):
	global logger
	logging.basicConfig(level=level)
	logger = logging.getLogger(arg0)

	global DELIMITER
	DELIMITER = os.environ.get('IFS', '\t')

	global EDITOR, EDITOR_BIN, EDITOR_ARGS
	try:
		res = os.environ['EDITOR'] if 'EDITOR' in os.environ else which(editor)
		EDITOR, EDITOR_BIN = os.path.basename(res), which(res)
	except StopIteration:
		logger.fatal("Unable to locate binary for editor: {!s}".format(os.environ.get('EDITOR', editor)))
		sys.exit(1)

	EDITOR_ARGS = os.environ.get('EDITOR_ARGS', '-f -O2' if 'vi' in EDITOR else '')
	return


def rename_file(a, b):
	parentdir = os.path.normpath(os.path.join(b, os.path.pardir)) if os.path.isdir(a) else os.path.dirname(b)
	try:
		if not os.path.isdir(parentdir):
			logger.info("creating base directory {:s} to contain {:s}".format(quote(parentdir), quote(b)))
			os.makedirs(parentdir)
	except Exception as E:
		logger.warning("os.makedirs({:s}) raised {!s}".format(quote(parentdir), E))
		return False

	try:
		result = os.rename(a, b)
	except Exception as E:
		logger.warning("os.rename({:s}, {:s}) raised {!s}".format(quote(a), quote(b), E))
		return False

	six.print_(DELIMITER.join([a, b]))
	logger.info("renamed: {:s} -> {:s}".format(quote(a), quote(b)))
	return True

def rename_output(a, b):
	simulate = logger.getChild('(simulated)')
	parentdir = os.path.normpath(os.path.join(b, os.path.pardir)) if os.path.isdir(a) else os.path.dirname(b)
	if not os.path.isdir(parentdir):
		simulate.info("creating base directory {:s} to contain {:s}".format(quote(parentdir), quote(b)))
		six.print_("mkdir -p \"{:s}\"".format(parentdir))
	if os.path.exists(a):
		simulate.info("renamed: {:s} -> {:s}".format(quote(a), quote(b)))
		six.print_("mv \"{:s}\" \"{:s}\"".format(a, b))
		return True
	simulate.warning("source file {:s} does not exist".format(quote(a)))
	return False

def rename(source, target):
	F = rename_output if arguments.dry_run else rename_file
	if arguments.dry_run:
		logger.warning("simulating the rename of {:d} entries from their source".format(len(source)))

	count = 0
	for a, b in szip(source, target):
		if a != b:
			count += int(F(a, b))
		continue
	return count

def listing(path):
	p = __ensure_text__(path, encoding=sys.getfilesystemencoding())
	for dirpath, _, filenames in os.walk(p):
		for name in sorted(filenames):
			yield os.path.join(dirpath, name)
		continue
	return

def dirlisting(path):
	p = __ensure_text__(path, encoding=sys.getfilesystemencoding())
	for dirpath, dirnames, _ in os.walk(p):
		for name in sorted(dirnames):
			yield os.path.join(dirpath, name)
	return

def edit(list):
	list = sfilter(None, list)

	[ logger.debug("edit({:d}) - found file {:d} -- {:s}".format(len(list), index, quote(name))) for index, name in enumerate(list) ]

	#hate python devers
	with tempfile.NamedTemporaryFile(prefix='renamer.', suffix='.source', delete=not WIN32) as t1, tempfile.NamedTemporaryFile(prefix='renamer.', suffix='.destination', delete=not WIN32) as t2:
		# really hate python devers
		smap(operator.methodcaller('close'), [t1, t2])
		with codecs.open(t1.name, 'w+b', encoding=FILEENCODING) as t1e, codecs.open(t2.name, 'w+b', encoding=FILEENCODING) as t2e:
			lines = smap(u'{:s}\n'.format, list)
			smap(operator.methodcaller('writelines', lines), [t1e, t2e])
			smap(operator.methodcaller('flush'), [t1e, t2e])

		logger.info("edit({:d}) - using source filename {:s}".format(len(list), quote(t1.name)))
		logger.info("edit({:d}) - using destination filename {:s}".format(len(list), quote(t2.name)))

		# switch the parameters so that the destination filename is first
		params = [EDITOR] + shlex.split(EDITOR_ARGS) + ['--', t2.name, t1.name]
		message = "os.spawnv(os.P_WAIT, {:s}, {:s})".format(quote(EDITOR_BIN), "[{:s}]".format(', '.join(map(quote, params))))

		logger.debug("edit({:d}) - calling {:s}".format(len(list), message))
		try:
			result = os.spawnv(os.P_WAIT, EDITOR_BIN, params)
		except Exception as E:
			logger.fatal("{:s} raised {!s}".format(message, E), exc_info=True)
			raise
		else:
			if result != 0: logger.warning("{:s} returned {:d}".format(message, result))

		#really hate python devers
		with codecs.open(t1.name, 'rb', encoding=FILEENCODING) as t1e, codecs.open(t2.name, 'rb', encoding=FILEENCODING) as t2e:
			smap(operator.methodcaller('seek', 0), [t1e, t2e])
			source, destination = t1e.readlines(), t2e.readlines()
			source, destination = smap(operator.methodcaller('strip'), source), smap(operator.methodcaller('strip'), destination)

		# restore the handles so that when we exit 'with', it won't double-close them.
		t1, t2 = smap(open, [t1.name, t2.name])

	if len(source) != len(list):
		logger.warning("edit({:d}) - source list has been modified from its original number of entries ({:d}) to a different number ({:d})".format(len(list), len(list), len(source)))
		logger.warning("edit({:d}) - using the modified source list (instead of the original) to rename files from".format(len(list)))
	elif any(x != y for x, y in szip(source, list)):
		logger.warning("edit({:d}) - source list has been modified from its originally listed entries".format(len(list)))
		logger.warning("edit({:d}) - using the modified source list (instead of the original) to rename files from".format(len(list)))
	else:
		source = list[:]

	if len(destination) != len(source):
		logger.error("edit({:d}) - destination list contains a different number of entries ({:d}) from the source ({:d})".format(len(list), len(destination), len(source)))
		logger.fatal("edit({:d}) - terminating...".format(len(list)))
		return [], []

	return source, destination

def main_files(*paths):
	source = []
	for p in paths:
		source.extend(listing(p))

	if len(source) == 0:
		logger.warning("main({:d}) - no files were found under the specified paths".format(len(paths)))
		logger.warning("main({:d}) - terminating...".format(len(paths)))
		return 0

	logger.info("main({:d}) - discovered {:d} file{:s} under the specified paths".format(len(paths), len(source), '' if len(source) == 1 else 's'))
	logger.info("main({:d}) - spawning editor for {:d} file{:s}".format(len(paths), len(source), '' if len(source) == 1 else 's'))
	time.sleep(1)

	# FIXME: compare newsource and target to see what's attempting to be renamed
	newsource, target = edit(source)
	count = rename(newsource, target)
	logger.info("main({:d}) - renamed {:s} file{:s}".format(len(paths), "{:d}".format(count) if count == 1 else "a total of {:d}".format(count), '' if count == 1 else 's'))
	return count

def main_directories(*paths):
	source = []
	for p in paths:
		source.extend(dirlisting(p))

	if len(source) == 0:
		logger.warning("main({:d}) - no directories were found under the specified paths".format(len(paths)))
		logger.warning("main({:d}) - terminating...".format(len(paths)))
		return 0

	logger.info("main({:d}) - discovered {:d} director{:s} under the specified paths".format(len(paths), len(source), 'y' if len(source) == 1 else 'ies'))
	logger.info("main({:d}) - spawning editor for {:d} director{:s}".format(len(paths), len(source), 'y' if len(source) == 1 else 'ies'))
	time.sleep(2)

	# FIXME: compare newsource and target to see what's attempting to be renamed
	newsource, target = edit(source)
	count = rename(newsource, target)
	logger.info("main({:d}) - renamed {:s} director{:s}".format(len(paths), "{:d}".format(count) if count == 1 else "a total of {:d}".format(count), 'y' if count == 1 else 'ies'))
	return count

if __name__ == '__main__':
	import sys
	name, arguments = parse_args()
	setup(name, logging.INFO if arguments.verbose else logging.WARNING)
	main = main_directories if arguments.use_dirs else main_files
	result = main(*arguments.paths)
	sys.exit(int(result <= 0))
