#require serve

Test raw style of hgweb

  $ hg init test
  $ cd test
  $ mkdir sub
  $ cat >'sub/some text%.txt' <<ENDSOME
  > This is just some random text
  > that will go inside the file and take a few lines.
  > It is very boring to read, but computers don't
  > care about things like that.
  > ENDSOME
  $ hg add 'sub/some text%.txt'
  $ hg commit -d "1 0" -m "Just some text"

  $ hg serve -p $HGPORT -A access.log -E error.log -d --pid-file=hg.pid

  $ cat hg.pid >> $DAEMON_PIDS
  $ (get-with-headers.py localhost:$HGPORT 'raw-file/bf0ff59095c9/sub/some%20text%25.txt' content-type content-length content-disposition) >getoutput.txt

  $ killdaemons.py hg.pid

  $ cat getoutput.txt
  200 Script output follows
  content-type: application/binary
  content-length: 157
  content-disposition: inline; filename="some text%.txt"
  
  This is just some random text
  that will go inside the file and take a few lines.
  It is very boring to read, but computers don't
  care about things like that.
  $ cat access.log error.log
  $LOCALIP - - [$LOGDATE$] "GET /raw-file/bf0ff59095c9/sub/some%20text%25.txt HTTP/1.1" 200 - (glob)

  $ rm access.log error.log
  $ hg serve -p $HGPORT -A access.log -E error.log -d --pid-file=hg.pid \
  > --config web.guessmime=True

  $ cat hg.pid >> $DAEMON_PIDS
  $ (get-with-headers.py localhost:$HGPORT 'raw-file/bf0ff59095c9/sub/some%20text%25.txt' content-type content-length content-disposition) >getoutput.txt
  $ killdaemons.py hg.pid

  $ cat getoutput.txt
  200 Script output follows
  content-type: text/plain; charset="ascii"
  content-length: 157
  content-disposition: inline; filename="some text%.txt"
  
  This is just some random text
  that will go inside the file and take a few lines.
  It is very boring to read, but computers don't
  care about things like that.
  $ cat access.log error.log
  $LOCALIP - - [$LOGDATE$] "GET /raw-file/bf0ff59095c9/sub/some%20text%25.txt HTTP/1.1" 200 - (glob)

  >>> with open('sub/binary.bin', 'wb') as fp:
  ...     fp.write(b'Binary\0file') and None

  $ hg ci -Aqm "add binary file" sub/
  $ hg serve -p $HGPORT -A access.log -E error.log -d --pid-file=hg.pid \
  > --config web.guessmime=True
  $ cat hg.pid >> $DAEMON_PIDS
  $ (get-with-headers.py localhost:$HGPORT 'annotate/tip/sub/binary.bin' content-type content-length content-disposition) >getoutput.txt
  $ cat getoutput.txt
  200 Script output follows
  content-type: text/html; charset=ascii
  
  <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
  <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-US">
  <head>
  <link rel="icon" href="/static/hgicon.png" type="image/png" />
  <meta name="robots" content="index, nofollow" />
  <link rel="stylesheet" href="/static/style-paper.css" type="text/css" />
  <script type="text/javascript" src="/static/mercurial.js"></script>
  
  <title>$TESTTMP/test: sub/binary.bin annotate</title> (glob)
  </head>
  <body>
  
  <div class="container">
  <div class="menu">
  <div class="logo">
  <a href="https://mercurial-scm.org/">
  <img src="/static/hglogo.png" alt="mercurial" /></a>
  </div>
  <ul>
  <li><a href="/shortlog/tip">log</a></li>
  <li><a href="/graph/tip">graph</a></li>
  <li><a href="/tags">tags</a></li>
  <li><a href="/bookmarks">bookmarks</a></li>
  <li><a href="/branches">branches</a></li>
  </ul>
  
  <ul>
  <li><a href="/rev/tip">changeset</a></li>
  <li><a href="/file/tip/sub/">browse</a></li>
  </ul>
  <ul>
  <li><a href="/file/tip/sub/binary.bin">file</a></li>
  <li><a href="/file/tip/sub/binary.bin">latest</a></li>
  <li><a href="/diff/tip/sub/binary.bin">diff</a></li>
  <li><a href="/comparison/tip/sub/binary.bin">comparison</a></li>
  <li class="active">annotate</li>
  <li><a href="/log/tip/sub/binary.bin">file log</a></li>
  <li><a href="/raw-file/tip/sub/binary.bin">raw</a></li>
  </ul>
  <ul>
  <li><a href="/help">help</a></li>
  </ul>
  </div>
  
  <div class="main">
  <h2 class="breadcrumb"><a href="/">Mercurial</a> </h2>
  <h3>
   annotate sub/binary.bin @ 1:<a href="/rev/7dc31308464a">7dc31308464a</a>
   <span class="phase">draft</span> <span class="branchhead">default</span> <span class="tag">tip</span> 
  </h3>
  
  
  <form class="search" action="/log">
  
  <p><input name="rev" id="search1" type="text" size="30" value="" /></p>
  <div id="hint">Find changesets by keywords (author, files, the commit message), revision
  number or hash, or <a href="/help/revsets">revset expression</a>.</div>
  </form>
  
  <div class="description">add binary file</div>
  
  <table id="changesetEntry">
  <tr>
   <th class="author">author</th>
   <td class="author">&#116;&#101;&#115;&#116;</td>
  </tr>
  <tr>
   <th class="date">date</th>
   <td class="date age">Thu, 01 Jan 1970 00:00:00 +0000</td>
  </tr>
  <tr>
   <th class="author">parents</th>
   <td class="author"></td>
  </tr>
  <tr>
   <th class="author">children</th>
   <td class="author"></td>
  </tr>
  </table>
  
  
  <form id="diffopts-form"
  data-ignorews="0"
  data-ignorewsamount="0"
  data-ignorewseol="0"
  data-ignoreblanklines="0">
  <span>Ignore whitespace changes - </span>
  <span>Everywhere:</span>
  <input id="ignorews-checkbox" type="checkbox" />
  <span>Within whitespace:</span>
  <input id="ignorewsamount-checkbox" type="checkbox" />
  <span>At end of lines:</span>
  <input id="ignorewseol-checkbox" type="checkbox" />
  </form>
  
  <script type="text/javascript">
      renderDiffOptsForm();
  </script>
  
  <div class="overflow">
  <table class="bigtable">
  <thead>
  <tr>
   <th class="annotate">rev</th>
   <th class="line">&nbsp;&nbsp;line source</th>
  </tr>
  </thead>
  <tbody class="stripes2 sourcelines"
         data-logurl="/log/tip/sub/binary.bin"
         data-selectabletag="TR"
         data-ishead="1">
    
  <tr id="l1" class="thisrev">
  <td class="annotate parity0">
  <a href="/annotate/7dc31308464a/sub/binary.bin#l1">
  1
  </a>
  <div class="annotate-info">
  <div>
  <a href="/annotate/7dc31308464a/sub/binary.bin#l1">
  7dc31308464a</a>
  add binary file
  </div>
  <div><em>&#116;&#101;&#115;&#116;</em></div>
  <div>parents: </div>
  <a href="/diff/7dc31308464a/sub/binary.bin">diff</a>
  <a href="/rev/7dc31308464a">changeset</a>
  </div>
  </td>
  <td class="source followlines-btn-parent"><a href="#l1">     1</a> (binary:application/octet-stream)</td>
  </tr>
  </tbody>
  </table>
  </div>
  </div>
  </div>
  
  <script type="text/javascript" src="/static/followlines.js"></script>
  
  
  
  </body>
  </html>
  
  $ (get-with-headers.py localhost:$HGPORT 'comparison/tip/sub/binary.bin' content-type content-length content-disposition) >getoutput.txt
  $ (get-with-headers.py localhost:$HGPORT 'file/tip/sub/binary.bin' content-type content-length content-disposition) >getoutput.txt
  $ (get-with-headers.py localhost:$HGPORT 'static/hgicon.png' content-type content-length content-disposition) >getoutput.txt
  $ killdaemons.py hg.pid
  $ cat access.log error.log
  $LOCALIP - - [$LOGDATE$] "GET /raw-file/bf0ff59095c9/sub/some%20text%25.txt HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /annotate/tip/sub/binary.bin HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /comparison/tip/sub/binary.bin HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /file/tip/sub/binary.bin HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /static/hgicon.png HTTP/1.1" 200 - (glob)

  $ cd ..
