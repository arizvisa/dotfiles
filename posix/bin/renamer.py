import sys,os
import tempfile,logging,time

### globals
EDITOR = os.environ.get('EDITOR', '/usr/local/bin/vim')
EDITOR_ARGS = os.environ.get('EDITOR_ARGS', '-O2')

### code
def help(argv0):
	print 'Usage: %s [-d] paths...'% argv0
	return

def rename_file(a,b):
	logging.info("renamed %s to %s", repr(a), repr(b))
	return os.rename(a,b)

def rename(source,target):
	count = 0
	for a,b in zip(source,target):
		if a != b:
			rename_file(a,b)
			count += 1
		continue
	return count

def listing(p):
	for dirpath,dirnames,filenames in os.walk(p):
		result = list(filenames)
		result.sort()
		for name in result:
			yield os.path.join(dirpath,name)
		continue
	return

def dirlisting(p):
	for dirpath,dirnames,filenames in os.walk(p):
		yield dirpath
	return

def edit(list):
	list = [_ for _ in list]

	with tempfile.NamedTemporaryFile(prefix='renamer.',suffix='.source') as t1:
		t1.write('\n'.join(list))
		t1.flush()

		with tempfile.NamedTemporaryFile(prefix='renamer.',suffix='.destination') as t2:
			t2.write('\n'.join(list))
			t2.flush()

			result = os.spawnv(os.P_WAIT, EDITOR, [EDITOR, EDITOR_ARGS, '--', t1.name, t2.name])
			if result != 0:
				logging.warning("os.spawnv(os.P_WAIT, %s, [%s, %s, '--', %s, %s]) returned %d", repr(EDITOR), repr(EDITOR), repr(EDITOR_ARGS), repr(t1.name), repr(t2.name))
			t2.seek(0)
			destination = [x.strip() for x in t2.readlines()]
		t1.seek(0)
		source = [x.strip() for x in t1.readlines()]

	if len([None for x,y in zip(source,list) if x != y]) > 0:
		logging.warning("renamer.edit(...) - source list was modified. ignoring.")

	if len(destination) != len(list):
		logging.fatal("renamer.edit(...) - destination list contains a different number of entries from the source. terminating. (%d != %d)", len(destination), len(list))
		return []

	return destination

def main_files(*paths):
	source = []
	for p in paths:
		source.extend(listing(p))

	if len(source) == 0:
		logging.warning("renamer.main(...) - found no files. terminating.")
		return

	logging.warning("renamer.main(...) - found %d files. spawning editor..", len(source))
	time.sleep(2)

	target = edit(source)
	count = rename(source,target)
	logging.warning("renamer.main(...) - renamed %d files.", count)
	return

def main_directories(*paths):
	source = []
	for p in paths:
		source.extend(dirlisting(p))

	if len(source) == 0:
		logging.warning("renamer.main(...) - found no directories. terminating.")
		return

	logging.warning("renamer.main(...) - found %d directories. spawning editor..", len(source))
	time.sleep(2)

	target = edit(source)
	count = rename(source,target)
	logging.warning("renamer.main(...) - renamed %d directories.", count)
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
	result = main(*arguments)
	sys.exit(int(result is not None))
