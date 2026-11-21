---
name: resolve-pr-comments
description: Resolve unresolved review threads on a pull request by fixing, replying, and resolving each. Use when asked to address PR review feedback or comments.
argument-hint: "PR number (default: the current branch's PR)"
metadata:
  audience: agent
---

# Resolve PR comments

1. Resolve the PR (`gh pr view [<number>] --json number,headRefName,url`) and work on its head branch in a worktree you own. If another session is actively editing the PR, coordinate per `pr-merge` before writing.
2. List unresolved threads:

   ```sh
   gh api graphql -F owner='{owner}' -F repo='{repo}' -F number=<PR> -f query='
     query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){
       pullRequest(number:$number){reviewThreads(first:100){nodes{
         id isResolved isOutdated path line comments(first:20){nodes{author{login} body url}}}}}}}' \
     --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved|not)'
   ```

3. For each thread, oldest first: read the whole thread and the code it points at; apply the fix following `flutter-standards`, or reply with the reason when no change is right; commit with the `commit` skill, referencing the thread URL.
4. Reply on the thread with the commit SHA, then resolve it:
   `gh api graphql -f query='mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}' -F id=<thread-id>`.
   Resolve outdated threads whose concern no longer applies with a one-line reply saying so.
5. Done when no unresolved thread remains, or each remaining one has a reply naming the owner decision it waits on. Run `make check`, push, and report resolved and open threads.
