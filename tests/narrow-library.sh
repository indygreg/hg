cat >> $HGRCPATH <<EOF
[extensions]
narrow=
[ui]
ssh=python "$RUNTESTDIR/dummyssh"
[experimental]
changegroup3 = True
EOF
