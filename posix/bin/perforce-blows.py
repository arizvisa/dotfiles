#!/usr/bin/env python2
## "fuck perforce"
##   -saltine

"""
Copyright (c) 2009, saltine [find me on freenode]
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this
   list of conditions and the following disclaimer in the documentation and/or
   other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER "AS IS" AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER
BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
"""


import os,sys,time
import urllib,string
from urlparse import urlparse,urljoin
from BeautifulSoup import BeautifulSoup

## perforce page specific stuff
def getLogViewSubdirs(soup, startwith=u'/depotTreeBrowser.cgi?'):
    subdirs = getParagraph(soup, u'Subdirs').find('table')
    if subdirs:
        urls = getTableUrls(subdirs)
        return [ (x,y) for x,y in urls if y.startswith(startwith) ]
    return []

def getLogViewFiles(soup, startwith=u'fileLogView.cgi?'):
    files = getParagraph(soup, u'Files').find('table')
    if files:
        urls = getTableUrls(files)
        return [ (x,y) for x,y in urls if y.startswith(startwith) and isValidPath(x) ]
    return []

def getFileViewerUrl(soup):
    '''given a fileLogView.cgi page, will return the url to the fileViewer.cgi page'''
    tables = soup.findAll('table')
    revisions = tables[2]
    rows = revisions.findAll('tr')
    latest = rows[1]
    columns = latest.findAll('td')
    anchor = columns[0].a
    return anchor['href']

def getFileContentsUrl(soup):
    url = soup.findAll(lambda x: x.name == 'a' and x.contents == [u'Download file'])
    assert url, 'Unable to find "Download file" link'
    return url[0]['href']

def fetchFromLogPage(fileLogPageUrl):
    soup = BeautifulSoup(getContent(fileLogPageUrl))
    url = urljoin(fileLogPageUrl, getFileViewerUrl(soup))
    soup = BeautifulSoup(getContent(url))
    url = urljoin(fileLogPageUrl, getFileContentsUrl(soup))
    return getContent(url)

## table url grabbing stuff
def getRowUrls(soup):
    '''returns all hrefs of all anchors inside a table row'''
    assert soup.name == u'td', 'Not a table row'
    anchors = soup.findAll('a')
    res = [(res.contents[0], res['href']) for res in anchors]
    return res

def getTableUrls(soup):
    assert soup.name == u'table', 'Not a table'
    rows = soup.findAll('td')
    return reduce(lambda x,y: x + getRowUrls(y), rows, [])

## pretty formatting shit
def stripBold(soup):
    assert soup.name == u'b', 'Not boldificationized'
    return soup.contents[0]

## basic utils
def log(message):
    sys.stderr.write( message + "\n" )

def getParagraph(soup, name):
    for res in soup.findAll('p'):
        l = list(res)
        if stripBold(l[0]) == name:
            return res
    raise SyntaxError

def getContent(url, timeout=60):
    try:
        return urllib.urlopen(url).read()

    except AttributeError:
        log('AttributeError raised trying to fetch %s\nRetrying in %d seconds'% (url, timeout) )

    except IOError:
        log('IOError raised trying to fetch %s\nRetrying in %d seconds'% (url, timeout) )

    time.sleep(timeout)
    return getContent(url)

def normalizeUrl(url):
    return urlparse(url).geturl()

def downloadFromLogPage(url, destination):
    log('download: %s'% destination)
    input = fetchFromLogPage(url)
    output = file(destination, 'wb')
    output.write(input)
    output.close()

def isValidPath(path):
    chars = "/-_.() %s%s" % (string.ascii_letters, string.digits)
    return len([ bool(c) for c in path if c in chars ]) == len(path)

## fetch start page
def fetchTree(start, target):
    soup = BeautifulSoup( getContent(start) )
    files = getLogViewFiles(soup)
    subdirs = getLogViewSubdirs(soup)

    ## get all files
    for name,path in files:
        urlpath = urljoin(start, path)
        filepath = '%s/%s'% (target, str(name))
        downloadFromLogPage(urlpath, str(filepath) )

    ## descend into subdirs if there are any
    for name,subdir in subdirs:
        urlpath = urljoin(start, subdir)
        filedir = '%s%s'% (target, str(name))
        os.makedirs(filedir)
        log('descend: %s'% filedir)
        fetchTree(urlpath, filedir)

if __name__ == '__main__':
    try:
        start = sys.argv[1]

    except IndexError:
        print 'try giving me a url to a /depotTreeBrowser.cgi'
        sys.exit()

    log('downloading tree from %s'% start)
    fetchTree(start, '.')
    log('complete')

