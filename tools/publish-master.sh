#!/bin/sh
# Make master the ja branch without its Japanese comments.
#
# Development happens on ja, whose sources carry Japanese comment lines
# (;;[ja] ..., any number of semicolons).  master is generated from it:
# the tree of ja (or of the commit given as $1), every such line
# deleted from the tracked files other than Markdown and vendor/, then
# the whole suite run on that tree, and only if it passes, one commit
# on master that names the ja commit it came from (Ja-Commit:).  The
# Japanese documents (*.ja.md) stay on both branches.  Nothing is
# pushed: `git push origin ja master` afterwards.
#
#   tools/publish-master.sh            # from ja
#   tools/publish-master.sh <commit>   # from a given commit of ja
set -eu
src=${1:-ja}
root=$(git rev-parse --show-toplevel)
cd "$root"
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "publish-master: commit or stash the working tree first" >&2
    exit 1
fi
sha=$(git rev-parse --verify "$src^{commit}")
ja_line='^[[:space:]]*;\+[[:space:]]*\[ja\]'

wt=$(mktemp -d "${TMPDIR:-/tmp}/scm2cpp-master.XXXXXX")
rmdir "$wt"
git worktree add -q "$wt" master
cleanup() { git worktree remove --force "$wt" 2>/dev/null || true; }
trap cleanup EXIT

cd "$wt"
# the tree of $sha, files it deleted included
git rm -rq --ignore-unmatch . >/dev/null
git checkout "$sha" -- .
git ls-files -z | grep -zv '\.md$' | grep -zv '^vendor/' \
    | xargs -0 -r grep -lZ "$ja_line" 2>/dev/null \
    | xargs -0 -r sed -i "/$ja_line/d"
git add -A
if git diff --cached --quiet; then
    echo "publish-master: master already matches $src ($sha)"
    exit 0
fi
if git ls-files -z | grep -zv '\.md$' | grep -zv '^vendor/' \
       | xargs -0 -r grep -lZ "$ja_line" 2>/dev/null | grep -qz .; then
    echo "publish-master: [ja] lines left after stripping" >&2
    exit 1
fi

# the suite, on exactly this tree
log=$(mktemp "${TMPDIR:-/tmp}/scm2cpp-master-tests.XXXXXX")
if ! ./run-tests.sh >"$log" 2>&1 || ! grep -q '^---- PASS=[0-9]* FAIL=0' "$log"; then
    echo "publish-master: the suite did not pass on the stripped tree; see $log" >&2
    exit 1
fi
result=$(grep '^---- PASS=' "$log")

# the message: the ja commits since the last publish
last=$(git log -1 --format=%B master | sed -n 's/^Ja-Commit: //p' | tail -1)
[ -n "$last" ] || last=$(git merge-base master "$sha")
count=$(git rev-list --count "$last..$sha")
if [ "$count" = 1 ]; then
    git log -1 --format=%B "$sha" | git interpret-trailers --trailer "Ja-Commit: $sha" >"$log.msg"
else
    { echo "Sync from ja ($count commits)"
      echo
      git log --reverse --format='- %s' "$last..$sha"
      echo
      echo "Japanese comment lines removed; suite on this tree: $result"
      echo
      echo "Ja-Commit: $sha"; } >"$log.msg"
fi
git commit -q -F "$log.msg"
echo "publish-master: master $(git rev-parse --short HEAD) from $src $(git rev-parse --short "$sha") ($result)"
