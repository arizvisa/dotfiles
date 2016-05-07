import sys,os,itertools,operator,functools,user,__builtin__

# use the current virtualenv if it exists
__builtin__._=os.path.join(user.home.replace('\\',os.sep).replace('/',os.sep),'.python-virtualenv','Scripts' if __import__('platform').system() == 'Windows' else 'bin', 'activate_this.py')
if os.path.exists(__builtin__._): execfile(__builtin__._,{'__file__':__builtin__._})

# add ~/.python/* to python module search path
map(sys.path.append,__import__('glob').iglob(os.path.join(user.home.replace('\\',os.sep).replace('/',os.sep),'.python','*')))
