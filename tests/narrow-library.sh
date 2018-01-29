cat >> $HGRCPATH <<EOF
[extensions]
narrow=
[ui]
ssh=python "$TESTDIR/dummyssh"
[experimental]
bundle2-exp = True
changegroup3 = True
EOF
