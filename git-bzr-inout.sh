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
  branch="$2"

  [ -d "$remote" ] || die "bzr repository must be local"

  [ -z "$branch" ] && branch="root:master"

  if expr "$branch" : "[^:]*:.*" &>/dev/null
  then
    rbnh="$(echo $branch|cut -d ':' -f 1)"
    lbnh="$(echo $branch|cut -d ':' -f 2)"
  else
    rbnh="$branch"
    if [ "$rbnh" = "root" ]; then
      lbnh="master"
    else
      lbnh="$branch"
    fi
  fi

  # Setup/checkout marks tracking branch

  # First time?
  if git branch --no-color|grep "^inout/$lbnh$" &>/dev/null
  then
    # no
    git checkout "inout/$lbnh" || die "Failed to checkout inout/$lbnh"

    gargs="--import-marks=$BASE/$lbnh.git"
  else
    # yes
    echo "Initializing $lbnh"

    git symbolic-ref HEAD "refs/heads/inout/$lbnh" \
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

  mv tmp.git $lbnh.git || echo "Missing tmp.git???"

  cat << EOF > .msg
$(basename $0) pull from $rbnh

remote $remote
EOF

  pushd "$remote" &>/dev/null || die "Failed to cd to $remote"

  bzr fast-export --plain -b $lbnh --marks=$BASE/$rbnh.bzr $rbnh | \
  git fast-import $gargs --export-marks=$BASE/tmp.git \
  || echo ">>>>>> Pull Error <<<<<<"

  popd &>/dev/null

  sort -g $rbnh.bzr > tmp.bzr2 || die "Failed to sort bzr output"
  mv tmp.bzr2 $rbnh.bzr || die "???"

  git add $rbnh.bzr $lbnh.git || die "Failed to add $rbnh.bzr $lbnh.git"

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
