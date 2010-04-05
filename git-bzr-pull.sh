#!/bin/bash
set -x

function die() {
  echo "$1" >&2
  exit 1
}

[ -d .git ] || die "Must be run from a normal git working directory"

git status -a &>/dev/null && die "Git working directory has uncommited changes"

BASE="$PWD"
export GIT_DIR="$PWD/.git"

# Parse arguments

remote="$1"
lbnh="$2"

[ -d "$remote" ] || die "bzr repository must be local"

if [ -z "$lbnh" ]
then
  lbnh="master"
fi

# Setup/checkout marks tracking branch

# First time?
if git branch --no-color|grep "^[ \*] inout$" &>/dev/null
then
  # no
  git checkout "inout" || die "Failed to checkout inout/$lbnh"

  gargs="--import-marks=$BASE/marks.git"
  bargs="--import-marks=$BASE/marks.bzr"
elif git branch -r --no-color|grep "^[ \*] origin/inout$" &>/dev/null
then
  # yes (from clone)
  git checkout -b "inout" "origin/inout" || die "Failed to checkout inout/$lbnh"

  gargs="--import-marks=$BASE/marks.git"
  bargs="--import-marks=$BASE/marks.bzr"
else
  # yes
  echo "Initializing $lbnh"

  git symbolic-ref HEAD "refs/heads/inout" \
  || die "Failed to create mark tracking branch"
  rm -f .git/index
fi

# remote - the bzr repository
# rbnh   - the bzr branch to be imported
# lbnh   - the git name of the imported branch

echo "Pull as $lbnh from $remote"

cat << EOF > .msg
$(basename $0) pull from $remote

remote $remote
EOF

pushd "$remote" &>/dev/null || die "Failed to cd to $remote"

bzr fast-export --plain -b $lbnh --marks=$BASE/marks.bzr . | \
git fast-import $gargs --export-marks=$BASE/tmp.git \
|| echo ">>>>>> Pull Error <<<<<<"

popd &>/dev/null

mv tmp.git marks.git || echo "Missing tmp.git???"

if head -n1 marks.bzr|grep '^format' &>/dev/null
then
  # ok
  echo -n
else
  # the header is backwards!
  head -n1 marks.bzr > h1 || die "Failed to extract header 1"
  head -n2 marks.bzr | tail -n1 > h2 || die "Failed to extract header 1"
  tail -n '+1' marks.bzr > b || die "Failed to extract body"
  cat h2 h1 b > marks.bzr || die "Failed to rebuild marks.bzr"
  rm -f h1 h2 b
fi

sort -g marks.bzr > tmp.bzr || die "Failed to sort bzr output"
mv tmp.bzr marks.bzr || die "???"

git add marks.bzr marks.git || die "Failed to add marks.bzr marks.git"

if git status -a &>/dev/null
then
  git commit -F .msg || die "Failed to commit marks changes"
else
  echo "No changes"
fi

rm -f .msg

echo "Done"
