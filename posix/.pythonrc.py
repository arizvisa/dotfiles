import sys,os,itertools,operator,functools,user,__builtin__

# use the current virtualenv
__builtin__._=os.path.join(user.home.replace('\\',os.sep).replace('/',os.sep),'.python-virtualenv','Scripts','activate_this.py')
execfile(__builtin__._,{'__file__':__builtin__._})

# add ~/.python/* to python module search path
map(sys.path.append,__import__('glob').iglob(os.path.join(user.home.replace('\\',os.sep).replace('/',os.sep),'.python','*')))
