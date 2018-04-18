cat >> $HGRCPATH <<EOF
[extensions]
narrow=
[ui]
ssh=python "$TESTDIR/dummyssh"
[experimental]
changegroup3 = True
EOF
