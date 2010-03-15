#!/bin/bash
set -x

function die() {
    echo "$1" >&2
    exit 1
}

function bzr-apply() {
    echo "Apply $1"

    local author="$(sed -n -e '/^From: / s/From: // p' "$1")"
    echo "By: $author"
    
    local msg="$(tempfile -d /tmp -pbzram)"
    echo "Message $msg"

    # Extract the commit message
    sed -n -e '/^Subject:/,/^\-\-\-/ p' "$1" \
    | sed -e '1 s/^Subject: //' \
    | head -n '-1' >> "$msg" \
    || die "Failed to write message"
    cat "$msg"

    # Extract and apply the patch
    echo "Testing patch"
    if sed -e '0,/^diff/d' "$1" | patch -p1 --dry-run
    then
        echo "Applying patch"
        sed -e '0,/^diff/d' "$1" | patch -p1 || die "Failed to apply tested patch?"
    else
        echo "Patch failed."
        rm -f "$msg"
        return 1
    fi

    # Add created files
    sed -n -e '/^--- \/dev\/null/,+1 p' "$1" \
    | sed -n -e '/^+++ / s/^+++ b\///p' \
    | while read ff
    do
        echo "Created $ff"
        bzr add "$ff" || die "Failed to add $ff"
    done \
    || die "Error adding created files"

    # Remove deleted files
    #   Automatic

    # Commit
    #echo "bzr commit --author=\"$author\" -F \"$msg\""
    bzr commit --author="$author" -F "$msg" || die "Failed to commit"

    rm -f "$msg"
}

for aa in "$@"
do

    case "$aa" in
    --*)
        arg="${aa#--}"
        ;;
    *)
        [ -f "$aa" ] || die "$aa is not a file"

        bzr-apply "$aa"
        ;;
    esac

done