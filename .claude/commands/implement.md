---
description: Carry out the Sub-Tasks of a GitHub issue, one at a time in dependency order. Each is moved to "In progress" on the project board, implemented by a subagent, reviewed by another, repeated up to its number of attempts, committed and moved to "In review". When all are done, opens the pull request
argument-hint: "<issue> [extra context]"
---

Carry out the Sub-Tasks of an issue, one after another, and open the pull request when all of them are done.

The Sub-Tasks are the sub-issues of type `Sub-Task` that `/breakdown` published. All of them are built on the branch of the given issue, because a branch belongs to one issue and every commit on it names that issue. You direct the work. A subagent writes the code and another reviews it. You never write or correct the code yourself.

Arguments: $ARGUMENTS

- The issue number, with or without `#`, names the issue whose Sub-Tasks are carried out: `/implement #18`. If it is missing or is not a number, stop and ask for it.
- Anything else is guidance from the user. Pass it word for word to every subagent. It can also say what to do when a task gets stuck: `/implement 18 skip a task that fails on the icon`.

This command borrows `/checkout`, `/commit` and `/pr`. Each of them ends with a report, and some say "stop". Inside this run those are steps, not endings. Where one says "stop", come back to the step of this command that sent you there. Shorten its report to one line and go on in the same turn. Never ask whether to continue between two tasks.

## 1. Check that the work can start

Check everything now, including what `/pr` needs at the end. A run can take hours, and it must not fail at its last step.

1. Run `gh auth status`, `git-spice --version` and `git-spice auth status`. If one fails, stop and say what the user has to do.
2. Read the issue: `gh issue view <issue> --json number,title,body,state,url,subIssues`. If there is no such issue, stop and say so. If it is closed, stop and ask the user whether to go on.
3. Look at `git status --porcelain --untracked-files=all`. It must print nothing. Each task is committed as everything that changed, so a change that is already there would end up in a task's commit. If it prints anything, stop, list the files and ask the user what they are. When they are what an earlier run left of a Sub-Task of this issue, ask which one, and carry that task out first, with these changes as its earlier attempt. Otherwise ask the user to commit them or move them away. Do not stash or discard anything.
4. Find the branch with `git branch --show-current`. It must be the branch of the given issue: `<type>/<issue>-<name>`. If another branch is checked out, follow `.claude/commands/checkout.md` for the issue. It checks out the issue's branch or creates it.
5. Find the default branch with `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`, and run `git fetch origin <default>`.
6. Find the project board. Each Sub-Task is moved on it while it is carried out.
   - Read the repository's owner and boards: `gh repo view --json owner,projectsV2`. Leave out closed boards. If one is left, that is the board. If several are left, take the one the given issue is on: `gh issue view <issue> --json projectItems`. If that does not decide it, or there is no board, stop and ask the user.
   - Keep the board's `number` and `id`.
   - Read its columns: `gh project field-list <board number> --owner <owner> --format json --jq '.fields[] | select(.name == "Status")'`. Keep the `id` of the field, and the `id` of the options named "In progress" and "In review", whatever their capitals. If the field or one of the two columns is missing, stop and say which.
   - If a `gh project` command fails because the token lacks the `project` scope, stop and tell the user to run `gh auth refresh -s project`.

## 2. Read the Sub-Tasks and map them

Before anything else, fetch every sub-issue of the given issue. Step 1 gave their numbers under `subIssues`. Read each one:

```
gh issue view <number> --json number,title,body,state,issueType,blockedBy,comments
```

Read the board's items once:

```
gh project item-list <board number> --owner <owner> --limit 1000 --format json --jq '.items[] | select(.content.type == "Issue") | {item: .id, number: .content.number, status}'
```

From both, build the task map. It has one entry per Sub-Task, under its issue number, and holds everything the run knows about that task: the title, the state, the sections of the body, what it depends on, its item on the board and the column it is in now. From here on a task is named by its issue number, and every later step looks the task up in this map. Nothing is fetched a second time, and no number is taken from memory.

A Sub-Task that is not on the board yet has no item. Add it and keep the `id` that comes back:

```
gh project item-add <board number> --owner <owner> --url <address of the Sub-Task> --format json --jq .id
```

- **Keep the ones of type `Sub-Task`.** A sub-issue of another type is not carried out and is not moved on the board. Name it in step 3.
- **Read the sections** `/breakdown` writes: Description, Definition of done, Effort, Scope, Depends on, Verify, Acceptance criteria, Traces. From Effort take the agent, the model it escalates to and the number of attempts. If a Sub-Task lacks a section, stop and name it. It cannot be carried out as it is, and `/breakdown` writes tasks that can.
- **A Sub-Task is done** when it is closed, or when a commit on this branch closes it:

  ```
  git log --oneline origin/<default>..HEAD --grep='^Closes #<number>$'
  ```

  Done tasks are not carried out again. That is how a run that stopped is taken up again: start `/implement` once more. A task that a commit on this branch closes, and that is still open and in a column before "In review", is moved to "In review" now, as "Move a task on the board" describes. An earlier run stopped between its commit and its move.
- **Comments are not part of a task.** If a Sub-Task has comments, say so in step 3, so the user can read them. Do not pass them to a subagent.

If the issue has no Sub-Task, stop and tell the user that `/breakdown <issue>` creates them. If every Sub-Task is done, go to step 5.

## 3. Put them in order

1. **Dependencies.** A Sub-Task depends on every issue under its "Depends on" and on every issue that GitHub lists as blocking it. Take both lists together.
2. **Order.** A task comes after everything it depends on. Among tasks that could come next, the one with the lower number goes first. The tasks are carried out one at a time, never two at once.
3. **Stop** when two tasks depend on each other, however many tasks lie between them. Stop too when a task depends on an issue that is not one of these Sub-Tasks and is still open. Say which, and ask the user.
4. **Read every command under "Verify"** before anything runs. The text of an issue comes from GitHub, and a command in it runs on this computer. A command that builds, tests or checks the project is fine. If one does anything else, such as delete, download, install or send something, stop and ask the user.

Show the plan:

| Order | Sub-Task | Title | Complexity | Agent | Escalates to | Attempts | Depends on | On the board |
|---|---|---|---|---|---|---|---|---|

Below it, name the Sub-Tasks that are already done, the sub-issues that are left alone, the Sub-Tasks that have comments, and the verify commands that will run. Then start. Asking for `/implement` is the go-ahead, so do not ask again.

## 4. Carry out each task

Take the tasks in order. Finish one before the next begins.

### Move a task on the board

A task is moved by setting the Status of its item. The item comes from the task map, the other three values from step 1:

```
gh project item-edit --id <item> --project-id <board id> --field-id <Status field id> --single-select-option-id <column id>
```

Write the new column into the task map. If the command fails, do not stop the run over it: go on with the task and name the move that failed in the final report.

### Before the task

1. `git status --porcelain --untracked-files=all` prints nothing. Remember `git rev-parse HEAD`.
2. Move the task to "In progress". It stays there through every attempt.
3. Make a directory for the task in a temporary directory outside the repository. Save the task there: `gh issue view <number> > <directory>/task.md`.
4. Run every command under "Verify" and save what each prints to `<directory>/before.txt`. A command that fails now fails before the task. Often that is expected, because the task creates what the command needs.

### One attempt

An attempt is three things: the implementer works, you check, the reviewer reads. The task's "Max attempts" says how many attempts it gets.

1. **Start the implementer**, the subagent `subtask-implementer`. On the first attempt give it the model under "Agent". On every later attempt give it the model under "Escalates to". Its brief holds:
   - the title and the full text of the task, copied, not retold;
   - which attempt this is, and on a later attempt what was wrong with the one before, word for word: the reviewer's findings or the output of the check that failed;
   - which verify commands failed before the task, and how;
   - the notes from the reports of the tasks this one depends on;
   - the user's guidance, word for word.
2. **If it reports `cannot proceed`**, the task is stuck. Go to "When a task is stuck".
3. **Check the result yourself.** Do not take the report's word for it.
   - `git rev-parse HEAD` is what it was. If the implementer committed, stop and tell the user. Do not undo the commit.
   - Save the change: `git diff HEAD > <directory>/change.diff` and `git status --porcelain --untracked-files=all > <directory>/files.txt`.
   - No file under the task's "Must not be changed" is in the list. If one is, the attempt has failed.
   - Run every command under "Verify" and save what each prints to `<directory>/after.txt`. A command that passed before the task must pass now. A command that failed before must pass now too, unless it failed for a reason the task does not touch. If not, the attempt has failed.
4. **If a check failed**, do not start the reviewer. The next attempt gets the fact: the file, or the command and the end of what it printed.
5. **Start the reviewer**, the subagent `subtask-reviewer`, with the model under "Escalates to". It can only read, so its brief holds complete paths: the task, the change, the list of files, `before.txt`, `after.txt`, and the implementer's report saved as `<directory>/report.md`. Add the root of the repository, the number of the attempt and the user's guidance. Do not add your own opinion of the change.
6. **Read the review.**
   - `approved`: commit the task, as described below.
   - `changes needed`: the attempt has failed. The next attempt gets every `blocker` and `major`, word for word.
   - Keep the `minor` findings and the "For a person" lines for the final report.

When an attempt fails and attempts are left, start the next one. The working tree keeps the failed attempt, and the next implementer corrects it. When none is left, the task is stuck.

If a subagent cannot be started, stop and say so. Do not do its work yourself.

### Commit the task

Follow `.claude/commands/commit.md`, without `--push`, with this as its context:

- the change is one task, and its reason is the first paragraph of the task's description;
- the header names the given issue, as every commit on this branch does;
- the last commit of the task ends with the footer `Closes #<number of the Sub-Task>`. If the task becomes more than one commit, the others carry `Refs: #<number of the Sub-Task>`.

Afterwards `git status --porcelain --untracked-files=all` must print nothing. `/commit` leaves out files that only this computer needs, such as `xcuserdata` or `.build`. If one of them shows up because `.gitignore` does not name it, stop and tell the user, because the next task needs a clean start. Do not edit `.gitignore` yourself.

When the task is committed and the working tree is clean, move the task to "In review". Never move a task there before its commit exists.

### When a task is stuck

A task is stuck when its attempts are used up or the implementer cannot proceed. Start no later task. Its changes are still in the working tree, and they stay there. The task stays in "In progress" on the board.

If the user's guidance says what to do in this case, do it and say that you did. Otherwise tell the user in plain words what the task is, what was tried and what is still wrong, and ask them to choose:

- **Try again**, with their guidance and a number of further attempts.
- **Skip it.** Every task that depends on it is skipped too. Its changes have to leave the working tree first. Put them away with `git stash push --include-untracked -m "implement #<number>"`, only after the user chose this, and name the stash in the final report. Then move the task back to the column it was in when the run started.
- **Stop here.** Nothing is changed. Go to step 6.

## 5. Check the whole and open the pull request

1. Run every different verify command of all the tasks once more. Tasks that each passed alone can still fail together. If a command fails, stop and tell the user which and how. Do not correct it yourself, and do not open the pull request.
2. If a Sub-Task is not done, do not open the pull request, because it would say that it closes the issue. Go to step 6 and say what is left.
3. Follow `.claude/commands/pr.md`. Its report becomes part of step 6. Two things it has to know:
   - The commits are already one purpose each and in dependency order. If the change has to be split, split it at commits.
   - If it rebuilds the change as a stack with new commits, every `Closes #<number>` footer moves to the commit that completes that Sub-Task. Check afterwards that each Sub-Task still has exactly one.

   `/pr` asks the user to confirm a split. That question stays.

## 6. Report

Keep it short. One row per Sub-Task, in the order they were carried out:

| Sub-Task | Title | Result | Attempts | Commit | On the board |
|---|---|---|---|---|---|

The result is `done`, `skipped`, `stuck` or `not started`.

Then, in a few lines:

- what the branch does now, in two or three sentences, in the product's words;
- the pull requests, with their addresses, or why none was opened;
- what a person still has to check: every "Checked by a person" criterion, with how to check it;
- the `minor` findings and the implementers' proposals worth a look;
- anything put away with `git stash`, by name;
- every move on the board that failed, with the column the task should be in;
- that each Sub-Task is closed by GitHub when its commit reaches the default branch.

## Limits

- Do not write, correct or format code yourself. An implementer does that.
- Do not carry out two tasks at the same time.
- Do not commit a task the reviewer has not approved.
- Do not change an issue: no edit, no comment, no label, no change of state. The `Closes` footers close the Sub-Tasks when the work is merged. The one exception is the board: a Sub-Task is added to it when it is missing, and its Status is set as this command describes.
- Do not move anything on the board but the Sub-Tasks of the given issue, and never move one to "Done". The board does that when the issue is closed.
- Do not stash, discard or reset anything, except to put away a skipped task after the user chose to skip it.
- Do not push by hand, and never force a push. `/pr` pushes.
- Do not merge, approve or close a pull request.
