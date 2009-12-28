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

cmd="$1"
shift

case "$cmd" in
pull|push)

  # Parse arguments

  remote="$1"
  rbnh="$2"
  lbnh="$3"

  [ -d "$remote" ] || die "bzr repository must be local"

  [ -z "$rbnh" ] && die "Must specify bazaar branch"

  if [ -z "$lbnh" ]
  then
    if [ "$rbnh" = "root" ]; then
      lbnh="master"
    else
      lbnh="$rbnh"
    fi
  fi

  # Setup/checkout marks tracking branch

  # First time?
  if git branch --no-color|grep "^[ \*] inout$" &>/dev/null
  then
    # no
    git checkout "inout" || die "Failed to checkout inout/$lbnh"

    gargs="--import-marks=$BASE/marks.git"
    bargs="--import-marks=$BASE/marks.bzr"
  elif git branch --no-color|grep "^origin/inout$" &>/dev/null
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

  ;;
*)
  [ -z "$cmd" ] || echo "Unknown command $cmd" >&2
  die "Usage $(basename $0) pull <repo> <rbranch[:lbranch]>"
  ;;
esac

# remote - the bzr repository
# rbnh   - the bzr branch to be imported
# lbnh   - the git name of the imported branch

case "$cmd" in
pull)
  echo "Pull $rbnh as $lbnh from $remote"

  cat << EOF > .msg
$(basename $0) pull from $rbnh as $lbnh

remote $remote
EOF

  pushd "$remote" &>/dev/null || die "Failed to cd to $remote"

  bzr fast-export --plain -b $lbnh --marks=$BASE/marks.bzr $rbnh | \
  git fast-import $gargs --export-marks=$BASE/tmp.git \
  || echo ">>>>>> Pull Error <<<<<<"

  popd &>/dev/null

  mv tmp.git marks.git || echo "Missing tmp.git???"

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
  ;;
push)
  echo "Push $rbnh from $lbnh to $remote"

  cat << EOF > .msg
$(basename $0) push to $rbnh from $lbnh

remote $remote
EOF

  git fast-export -M -C $gargs --export-marks=$BASE/tmp.git $lbnh | \
  bzr fast-import $bargs --export-marks=$BASE/tmp.bzr - \
  || echo ">>>>>> Push Error <<<<<<"

  mv tmp.git marks.git || echo "Missing tmp.git???"

  sort -g tmp.bzr > marks.bzr || die "Failed to sort bzr output"

  git add marks.bzr marks.git || die "Failed to add marks.bzr marks.git"

  if git status -a &>/dev/null
  then
    git commit -F .msg || die "Failed to commit marks changes"
  else
    echo "No changes"
  fi

  rm -f .msg
  ;;
esac
echo "Done"
