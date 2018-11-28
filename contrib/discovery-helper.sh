#!/bin/bash
#
# produces two repositories with different common and missing subsets
#
#   $ discovery-helper.sh REPO NBHEADS DEPT
#
# The Goal is to produce two repositories with some common part and some
# exclusive part on each side. Provide a source repository REPO, it will
# produce two repositories REPO-left and REPO-right.
#
# Each repository will be missing some revisions exclusive to NBHEADS of the
# repo topological heads. These heads and revisions exclusive to them (up to
# DEPTH depth) are stripped.
#
# The "left" repository will use the NBHEADS first heads (sorted by
# description). The "right" use the last NBHEADS one.
#
# To find out how many topological heads a repo has, use:
#
#   $ hg heads -t -T '{rev}\n' | wc -l
#
# Example:
#
#  The `pypy-2018-09-01` repository has 192 heads. To produce two repositories
#  with 92 common heads and ~50 exclusive heads on each side.
#
#    $ ./discovery-helper.sh pypy-2018-08-01 50 10

set -euo pipefail

if [ $# -lt 3 ]; then
     echo "usage: `basename $0` REPO NBHEADS DEPTH"
     exit 64
fi

repo="$1"
shift

nbheads="$1"
shift

depth="$1"
shift

leftrepo="${repo}-left"
rightrepo="${repo}-right"

left="first(sort(heads(all()), 'desc'), $nbheads)"
right="last(sort(heads(all()), 'desc'), $nbheads)"

leftsubset="ancestors($left, $depth) and only($left, heads(all() - $left))"
rightsubset="ancestors($right, $depth) and only($right, heads(all() - $right))"

echo '### building left repository:' $left-repo
echo '# cloning'
hg clone --noupdate "${repo}" "${leftrepo}"
echo '# stripping' '"'${leftsubset}'"'
hg -R "${leftrepo}" --config extensions.strip= strip --rev "$leftsubset" --no-backup

echo '### building right repository:' $right-repo
echo '# cloning'
hg clone --noupdate "${repo}" "${rightrepo}"
echo '# stripping:' '"'${rightsubset}'"'
hg -R "${rightrepo}" --config extensions.strip= strip --rev "$rightsubset" --no-backup
