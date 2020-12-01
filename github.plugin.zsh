#!/usr/bin/env bash
# shellcheck disable=SC1090

export PATH=${0:A:h}/bin:$PATH

GITHUB_TOKEN_FILE="${GITHUB_TOKEN_FILE:-$XDG_CONFIG_HOME/.github_token}"
GITHUB_TOKEN="$(head -n 1 $GITHUB_TOKEN_FILE)"
GITHUB_GITHUB_API_URL="https://api.github.com"
GITHUB_PER_PAGE=100

__github_is_user() {
  local name="$1"

  curl -I -X GET "${GITHUB_GITHUB_API_URL}/users/${name}" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    --compressed | grep Status: | awk '{print $2}'
}

__github_is_org() {
  local name="$1"

  curl -I -X GET "${GITHUB_GITHUB_API_URL}/orgs/${name}" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    --compressed | grep Status: | awk '{print $2}'
}

__github_query_repos() {
  local query="$1"
  local page="${2:-1}"

  curl -X GET "${GITHUB_GITHUB_API_URL}/search/repositories?q=${query}&GITHUB_PER_PAGE=${GITHUB_PER_PAGE}&page=${page}" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    --compressed
}

__github_search_repos() {
  local name="$1"
  local term="$2"

  count=$GITHUB_PER_PAGE
  page=1
  while [ "$count" -eq "$GITHUB_PER_PAGE" ]
  do
    repos=$(query_repos "${term}+org:${name}" "$page" | jq '.items[].name')
    count=$(echo "$repos" | wc -l)
    if [ "$count" = "$GITHUB_PER_PAGE" ]
    then
      page=$((page + 1))
    fi
    echo "$repos"
  done
}

__github_set_default_branch() {
  local owner="$1"
  local repo="$2"
  local branch="$3"

  curl -X PATCH "${GITHUB_GITHUB_API_URL}/repos/${owner}/${repo}" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    --data "{\"default_branch\": \"$branch\" }" \
    --compressed
}

__github_list_repos() {
  local type="$1"
  local name="$2"
  local page="${3:-1}"

  curl -X GET "${GITHUB_GITHUB_API_URL}/${type}/${name}/repos?GITHUB_PER_PAGE=${GITHUB_PER_PAGE}&page=${page}" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    --compressed
}

__github_clone_repos() {
  local type="$1"
  local name="$2"
  local dir="${HOME}/src/github.com/${name}"
  mkdir -p "$dir"
  cd "$dir"

  count=$GITHUB_PER_PAGE
  page=1
  while [ "$count" -eq "$GITHUB_PER_PAGE" ]
  do
    repos="$(__github_list_repos "$type" "$name" "$page" | jq '.[].clone_url')"
    count=$(echo "$repos" | wc -l)
    echo "request page $page returned $count"
    page=$((page + 1))
    echo "$repos" | xargs -n 1 git clone
  done
}
