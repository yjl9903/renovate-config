#!/usr/bin/env bash
set -euo pipefail

main_ref=refs/remotes/origin/main
deps_ref=refs/remotes/origin/deps
deps_target=refs/heads/deps

fetch_branches() {
  git fetch --prune origin '+refs/heads/*:refs/remotes/origin/*'
}

push_deps() {
  local expected_deps=$1 source_ref=$2
  git push --force-with-lease="${deps_target}:${expected_deps}" origin "${source_ref}:${deps_target}"
}

rebase_in_progress() {
  test -d "$(git rev-parse --git-path rebase-merge)" ||
    test -d "$(git rev-parse --git-path rebase-apply)"
}

rebase_with_main_winning() {
  local path
  local -a conflicts

  if git rebase "$main_ref"; then
    return
  fi
  rebase_in_progress || return 1

  while rebase_in_progress; do
    conflicts=()
    while IFS= read -r -d '' path; do
      conflicts+=("$path")
    done < <(git diff --name-only --diff-filter=U -z)

    if (( ${#conflicts[@]} == 0 )); then
      echo '::error::Rebase stopped without conflicted files.'
      git status --short
      return 1
    fi

    # During a rebase, "ours" is the branch onto which the commits are replayed.
    for path in "${conflicts[@]}"; do
      if git rev-parse --verify --quiet ":2:$path" >/dev/null; then
        git --literal-pathspecs checkout --ours -- "$path"
        git --literal-pathspecs add -- "$path"
      else
        git --literal-pathspecs rm --force --ignore-unmatch -- "$path"
      fi
    done

    if git diff --cached --quiet; then
      if ! git rebase --skip; then
        rebase_in_progress || return 1
      fi
    elif ! GIT_EDITOR=true git rebase --continue; then
      rebase_in_progress || return 1
    fi
  done
}

refresh_lockfile() {
  local -a other_paths=(. ':(exclude)pnpm-lock.yaml')

  # Read the tool versions from the rebased checkout on each attempt.
  mise exec -- pnpm install --no-frozen-lockfile

  if ! git diff --quiet -- "${other_paths[@]}" || ! git diff --cached --quiet -- "${other_paths[@]}"; then
    echo '::error::pnpm install changed files other than pnpm-lock.yaml.'
    git status --short
    return 1
  fi

  git add pnpm-lock.yaml
  if ! git diff --cached --quiet; then
    git commit -m 'chore(deps): refresh lockfile after syncing main'
  fi
}

sync_deps() {
  local attempt expected_deps

  git config user.name 'github-actions[bot]'
  git config user.email '41898282+github-actions[bot]@users.noreply.github.com'

  for attempt in 1 2 3; do
    fetch_branches

    if ! git show-ref --verify --quiet "$deps_ref"; then
      echo '::notice::deps does not exist. Creating it from main.'
      # An empty lease only permits creating a branch that is still absent.
      if push_deps '' "$main_ref"; then
        return
      fi

      echo '::warning::Could not create deps. Retrying.'
      continue
    fi

    expected_deps="$(git rev-parse "$deps_ref")"
    git checkout -B deps "$deps_ref"

    if git diff --quiet "$main_ref" "$deps_ref"; then
      # The trees match after a squash merge, but the commit histories differ.
      git reset --hard "$main_ref"
    else
      rebase_with_main_winning
    fi

    refresh_lockfile

    if push_deps "$expected_deps" HEAD; then
      return
    fi

    echo "::warning::Could not push deps on attempt ${attempt}. Retrying."
  done

  echo '::error::Could not synchronize deps after three attempts.'
  return 1
}

reset_deps() {
  local current_deps

  fetch_branches

  if ! git show-ref --verify --quiet "$deps_ref"; then
    echo '::notice::deps has already been deleted.'
    return
  fi

  current_deps="$(git rev-parse "$deps_ref")"
  if [[ "$current_deps" != "$MERGED_DEPS_SHA" ]]; then
    echo '::notice::deps advanced after the PR was merged. Keeping the newer commits.'
    return
  fi

  push_deps "$current_deps" "$main_ref"
}

open_rollup_pr() {
  local existing_pr

  fetch_branches

  if ! git show-ref --verify --quiet "$deps_ref"; then
    echo '::notice::deps has been deleted.'
    return
  fi

  if git diff --quiet "$main_ref" "$deps_ref"; then
    echo 'deps and main have identical content. No pull request is needed.'
    return
  fi

  existing_pr="$(
    gh pr list \
      --state open \
      --base main \
      --head deps \
      --json number \
      --jq '.[0].number // empty'
  )"

  if [[ -n "$existing_pr" ]]; then
    echo "Pull request #${existing_pr} already rolls deps into main."
    return
  fi

  gh pr create \
    --base main \
    --head deps \
    --title 'chore: update deps' \
    --body $'This PR collects the dependency updates merged into the dependency branch.

Review the combined changes and squash-merge this PR when the rollup is ready.'
}

case "$1" in
  sync) sync_deps ;;
  reset) reset_deps ;;
  open-pr) open_rollup_pr ;;
  *) echo "::error::Unknown rollup operation: $1"; exit 1 ;;
esac
