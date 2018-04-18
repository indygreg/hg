scratchnodes() {
  for node in `find ../repo/.hg/scratchbranches/index/nodemap/* | sort`; do
     echo ${node##*/} `cat $node`
  done
}

scratchbookmarks() {
  for bookmark in `find ../repo/.hg/scratchbranches/index/bookmarkmap/* -type f | sort`; do
     echo "${bookmark##*/bookmarkmap/} `cat $bookmark`"
  done
}

setupcommon() {
  cat >> $HGRCPATH << EOF
[extensions]
infinitepush=
[ui]
ssh = python "$TESTDIR/dummyssh"
[infinitepush]
branchpattern=re:scratch/.*
EOF
}

setupserver() {
cat >> .hg/hgrc << EOF
[infinitepush]
server=yes
indextype=disk
storetype=disk
reponame=babar
EOF
}

waitbgbackup() {
  sleep 1
  hg debugwaitbackup
}

mkcommitautobackup() {
    echo $1 > $1
    hg add $1
    hg ci -m $1 --config infinitepushbackup.autobackup=True
}

setuplogdir() {
  mkdir $TESTTMP/logs
  chmod 0755 $TESTTMP/logs
  chmod +t $TESTTMP/logs
}
