---
description: Split a GitHub issue or a feature description into tasks. Reads the issue and the issues above it, proposes self-contained tasks, and after the user confirms publishes them as sub-issues of type Sub-Task
argument-hint: "<issue | feature description> [extra context]"
---

Split a piece of work into tasks, show them to the user, and publish them on GitHub once the user agrees.

A task is one coherent change that one person or one AI agent can make and check without asking anyone. The tasks are later carried out with `/implement <the issue>`: one at a time, in dependency order, on the branch of the issue they split, each as a commit of its own.

Arguments: $ARGUMENTS

- An issue number, with or without `#`, names the issue to split: `/breakdown #18`. The tasks become its sub-issues.
- Text after the number is context. It can narrow the job or add a decision: `/breakdown 18 leave the icon for a later task`.
- Text with no number is a feature description: `/breakdown let the user choose which display shows the wallpaper`. Step 1 asks which issue the tasks go under.
- With no argument, stop and ask for an issue number or a description.

## 1. Read the work

1. Run `gh auth status`. If `gh` is missing or not signed in, stop and say what the user has to do.
2. With a description only, the description is the work, but the tasks still need an issue to go under. Ask the user which existing issue that is. Read it and the issues above it as the next steps say: they give the rules, the words and the work that already exists. If the user says there is no such issue yet, go to step 2 with the description alone.
3. Read the issue, with its comments:

   ```
   gh issue view <number> --json number,title,body,state,url,milestone,issueType,parent,subIssues,blockedBy,comments
   ```

   If there is no such issue, stop and say so. If it is closed, stop, say so, and ask the user whether to go on.
4. Read every issue above it. `parent` gives only a number and a title, so read each one in turn until an issue has no parent:

   ```
   gh issue view <parent> --json number,title,body,state,url,milestone,parent,subIssues
   ```

   The issue says what to do. The issues above it say why, what the words mean, which rules hold and which acceptance criteria the work serves. An epic is the feature's specification: its definitions, rules, non-goals and acceptance criteria bind every task under it.
5. Look at the work that already exists, so that no task repeats it:
   - the sub-issues of the given issue. If it has some, plan only what they leave out, and say so in step 6;
   - the other sub-issues of its parent. They are neighbours: their work is not this issue's work. Read the body of one whose title suggests it overlaps.

## 2. Explore the repository

A task names real files and real commands, so they have to be found before a task is written. Two scouts do that, each in a context of its own, so the files they read do not fill yours. Both can only read and search.

| Scout | What it reports |
|---|---|
| `breakdown-code-scout` | The code the work touches today: the files and what they hold, the exact shape of the types the work will use, the file to follow, where files of each kind live, the files several tasks would share |
| `breakdown-verify-scout` | How the work can be checked: the commands that build and test, as the repository writes them, how to run one test, where tests live and how they are written, what is checked on a pull request |

Start both in one message, so they work at the same time. Do it before step 3: a scout that is shown a split only confirms it.

### The brief

A scout knows the repository, the project's rules and what you send it, and nothing else. It has not seen the issues. Send both the same brief:

- **The work.** What the issue asks for, in full: its scope and its "done when", copied, not retold. Add the rules, the definitions and the acceptance criteria from the issues above it that this work must meet, with their text.
- **The words.** The product's words that the work uses, each with the other spellings a search should try: `slot`, `Slot`, `slots`, `timeOfDay`.
- **Not this work.** What the neighbours and the existing sub-issues cover, so the scout leaves it out.
- **Questions.** What you need to know to split the work, one per line. "Is there a string catalogue yet, and where?" "Which type holds a wallpaper's pictures, and how is one added?"

Do not put a proposed split, a list of tasks or a file you hope exists into the brief.

### The reports

- A report is a lead, not a proof. Before a task states a declaration, open the lines the scout named and copy from the file. Before a task lists a file to update or delete, see that the file is there.
- "Does not exist yet" is a result. A task has to create what is missing, and no task can use it before that task is done.
- When a report leaves open something that changes the split, send that scout the question, or start it again with a narrower brief. When the repository cannot answer it, ask the user before you go on. Do not guess.
- If a scout cannot be started, or replies that it has no tool to search with, do its work yourself, as its file in `.claude/agents` describes. Say so in step 6.

The rules in `.claude/rules` are already in your context. They decide where a file goes and what a task must include: the layer of every Swift file, the changelog entry for a change a user can notice, the errors each layer defines.

## 3. Split the work

- **One task, one coherent change.** Usually one to eight files, and one purpose, because each task is committed by itself and a commit has one purpose. A task of more than about 400 changed lines is too large to review well: split it.
- **Tests travel with the code they test**, in the same task.
- **Split along the layers.** The usual order is `Domain`, `Application`, `Infrastructure`, `Presentation`, `Features`, and last the composition root that connects them. A port and the use case that needs it belong together. Its adapter is a task of its own.
- **Do not split what has to be designed together.** Two parts that share one rule belong in one task.
- **Each file has as few tasks as possible.** Two tasks that touch the same file cannot be done at the same time, so one of them depends on the other. The project file, the package manifest, the string catalogue, `README.md` and `CHANGELOG.md` are such files. One last task that connects everything is often better than three that each edit the same file.
- **A task that makes something a user can notice** also updates `CHANGELOG.md`, as `.claude/rules/changelog.md` says.
- **Stay inside the issue.** Every task serves something the issue asks for. Work that belongs to a neighbour or to a non-goal of the epic is left out, and named in step 6.
- **As few tasks as the work needs.** If the whole issue is one coherent change, it is already a task. Say so, publish nothing and stop.

Order the tasks so that none needs one that comes after it. Give each a working id in that order: `T-001`, `T-002`, and so on. The ids exist only until the tasks are published.

## 4. Write each task

The implementer sees the task and the repository, and nothing else. Write so that they can build it, test it and know it is done without guessing.

- **Restate, never point.** Do not write "as the epic says" or "see #2". Write the rule itself, in the task.
- **State facts about the code.** For new code: what to build, where, and which file to follow. For a change: what the code does now and where, then what it must do.
- **Give contracts in full.** When a task uses something another task creates, write its exact name and shape in the sentence: the type, the method, the parameters, the errors. The implementer cannot read the other task. Name another task only when this one depends on it, and by its working id.
- **Carry the why**, in the product's words. One sentence on what the user gains becomes the reason in the commit message.
- **Write for both readers.** The first paragraph tells a person in plain language what the task delivers. The rest gives an agent the detail. Code names go in backticks.
- **Cut the rest.** Every sentence changes what the implementer does.

### The fields

The title of the issue is the task's name: imperative, specific, at most 100 characters. "Create the app project with one module per layer", not "Project work". It is plain words: no backticks, no quotation marks and no `$`, because it is typed into a shell command.

The body has these sections, in this order and with these headings. Each holds one field of the task format, so a script or an agent can turn the body back into data.

| Section | Field | What it holds |
|---|---|---|
| `## Description` | `description` | What to build or change, where, which file to follow, the contracts it uses and the ones it gives to later tasks, the edge cases, and the why |
| `## Definition of done` | `definition_of_done` | One sentence that names the result someone can observe |
| `## Effort` | `complexity`, `agent`, `escalates_to`, `max_attempts` | A table of one row |
| `## Scope` | `scope.touch`, `scope.forbidden` | Every file the task creates, updates or deletes, and the files it must leave alone |
| `## Depends on` | `depends_on` | The tasks that must be finished first, each with what this task uses from it |
| `## Verify` | `verify` | The commands that prove the task works, run from the root of the repository |
| `## Acceptance criteria` | `acceptance_criteria` | Statements that can be checked, as a list of checkboxes |
| `## Traces` | `traces` | The ids from the epic that the task serves |

- **Effort.** Score the complexity from 1 to 10. The score decides the agent:

  | Complexity | Typical work | Agent | Escalates to | Max attempts |
  |---|---|---|---|---|
  | 1–2 | A setting, a constant, a rename, a text | `sonnet` | `opus` | 2 |
  | 3–4 | One more instance of a pattern that exists, or a local change with a few tests | `sonnet` | `opus` | 2 |
  | 5–6 | Several files and some judgment: a use case with its port, a screen with its state | `opus` | `fable` | 3 |
  | 7 | Tricky logic: concurrency, state that must not be left half changed, a rule that crosses layers | `opus` | `fable` | 3 |
  | 8–10 | A new design with nothing to follow, or a large change whose parts cannot be separated | `fable` | `fable` | 3 |

  Add one attempt when the work is fiddly but mechanical. Never more than 5.
- **Scope.** Exact paths from the root of the repository, with no wildcards, each with `create`, `update` or `delete`. A file to create does not exist yet. A file to update or delete exists now, or a task this one depends on creates it. Include the test files. A file that is only read is not listed. Under "Must not be changed", name what the implementer could be tempted to edit but must not: files another task owns, generated files, the rules and hooks in `.claude`. Paths or wildcards, a short list, or "Nothing." Never a file that is also in the table.
- **Depends on.** Direct dependencies only. Add one when the task uses what another task produces, or when both touch the same file. "Nothing." when there are none.
- **Verify.** Commands taken from the verify scout's report. A command may use a file, a scheme or a script only when it exists now, or when this task or a task it depends on creates it. When the scout found no command because the project cannot be built yet, the task that makes it buildable states the command: it writes it into `README.md` and gives it in full in its description, so that later tasks can name it. No other command is invented. Narrow the tests to the ones the task adds where the tool allows it. Every task has at least one command. What only a person can see, such as how a window looks, is an acceptance criterion that starts with "Checked by a person:", next to a command that proves the app still builds.
- **Acceptance criteria.** Each one is a test case or a check a person can make. Cover the normal case and every failure the task owns. When the task changes something that worked, keep one criterion that proves it still works.
- **Traces.** The ids of the epic's acceptance criteria and user stories that the task serves, such as `AC-F02-14` or `US-F02-05`. This is the only place an id from another issue appears. "None." when the work has no such ids.

### The body

```
## Description

<What the task delivers and why, in one or two plain sentences.>

<What to build or change, where, which file to follow, the contracts, the edge cases.>

## Definition of done

<One sentence.>

## Effort

| Complexity | Agent | Escalates to | Max attempts |
|---|---|---|---|
| 4 of 10 | sonnet | opus | 2 |

## Scope

| File | Action |
|---|---|
| `<path>` | create |
| `<path>` | update |

Must not be changed:

- `<path or wildcard>`

## Depends on

- #<number> <title>: <what this task uses from it>

## Verify

- `<command>`
- `<command>`

## Acceptance criteria

- [ ] <statement that can be checked>
- [ ] <statement that can be checked>

## Traces

`AC-F02-01`, `AC-F02-14`
```

In the draft, a task names another task by its working id, such as `T-002`. Step 7 replaces every one of them with an issue number.

## 5. Check the set

Before you show anything, check the tasks against each other and correct what fails.

- Every item the issue asks for, in its scope and in its "done when", belongs to a task. Nothing is left over.
- No task does work the issue does not ask for.
- No task depends on a later one, and no two tasks depend on each other.
- Every working id in a task's text is also under its "Depends on".
- Two tasks that touch the same file are joined by a dependency.
- Every file to update or delete exists, or an earlier task creates it. No file is created twice. You have looked for each one yourself, whatever a scout reported.
- Every declaration a task quotes from existing code was copied from the file, not from a report.
- Every command under "Verify" can run when its task is finished.
- The agent, the escalation and the attempts match the complexity.
- No section is empty, and no task says "see" another issue for something the implementer needs.

### The coverage review

Your own check of coverage is not enough, because you wrote the tasks. A reviewer who has not seen your reasoning reads the issues and the tasks and says what no task proves. It is the subagent `breakdown-coverage-reviewer`. It can only read files, so give it the texts as files.

1. Make a temporary directory outside the repository, with `issues` and `tasks` in it.
2. Save the text of every issue the review needs, each in a command of its own:

   ```
   gh issue view <number> > <directory>/issues/<number>.md
   ```

   That is the given issue, every issue above it, every sub-issue it already has, and the other sub-issues of every issue above it. For an issue that has comments, add them to its file with `gh issue view <number> --comments >> <directory>/issues/<number>.md`. With a description and no issue, save the description, word for word, as `issues/description.md`.
3. Write the full body of every task to `<directory>/tasks/<working id>.md`. From here on these files are the tasks. Every later correction, yours or the user's, is made in the file, and a task that is taken out loses its file. Step 6 shows what the files say, and step 7 publishes them.
4. Start the reviewer. It cannot search, so give every file as a complete path. Its brief holds only:
   - the issue being split: number, title and file;
   - the issues above it, nearest first: number, title and file;
   - the sub-issues that exist and the neighbours: number, title, state and file;
   - what the user decided, word for word: the context from the arguments, and every change asked for in step 6;
   - the tasks: working id, title and file.

   Do not send your own table of coverage, your reasons or anything a scout reported. A reviewer that is shown your answer confirms it.

Act on every finding:

- `gap` and `partly`: something the issue asks for has no acceptance criterion that proves it. Add the criterion to the task it belongs to, or add a task.
- `extra`, `non-goal` and `neighbour`: a task does what nobody asked of this issue. Take it out. Keep it only when another task cannot work without it, and say so in step 6.
- `contradiction` and `trace`: correct the task.
- "Covered by no issue yet" is not a fault of your tasks. It is work of the feature that no issue asks for so far. Do not add tasks for it: that breaks "stay inside the issue". Show it to the user in step 6.
- You may disagree with a finding. Then leave the task as it is and give your reason in step 6. Never drop a finding without a word.

When a finding made you add or remove a task or change an acceptance criterion, run the checks of this step again and start the reviewer once more with the new files. Two reviews are the most for one list. What the second one still finds goes to the user in step 6.

If the reviewer cannot be started, or replies that it cannot read the files, check the coverage yourself as `.claude/agents/breakdown-coverage-reviewer.md` describes, and say in step 6 that no independent review was made.

## 6. Ask the user to confirm

Show:

1. The work, in one line: the issue's number and title, or the description.
2. The tasks, one row each:

   | Task | Title | Complexity | Agent | Depends on | Files | Serves |
   |---|---|---|---|---|---|---|

3. For each task, its first paragraph and its definition of done.
4. Coverage, from the review: each thing the issue asks for, with the task and the acceptance criterion that proves it. Then every finding of the reviewer, with what you changed or why you left the task as it is.
5. The rest of the feature: which of its goals, rules and acceptance criteria other issues cover, and which no issue covers yet. These are not part of this list. They tell the user which issues are still to be written.
6. What was left out and why: work of a neighbour, a non-goal, sub-issues that already exist.
7. Every task of complexity 8 or more, with what makes it hard and a recommendation: keep it whole because its parts must be thought about together, or split it and how.
8. Where the full texts are, as complete paths.
9. What publishing will do: how many issues, under which issue, with which milestone.

Then ask the user to choose: publish, change or cancel.

Tasks are published under an issue. If step 1 found none, ask again which existing issue they go under. Read it as step 1 says, correct the tasks where its rules or its existing sub-issues change them, run step 5 again with the review, and show the list again. Create a new parent issue only when the user asks for one, and show its title and text for confirmation with the list.

- **Change**: apply what the user says, run the checks of step 5 again, and show the list again. Start the reviewer again only when a task was added or removed or an acceptance criterion changed, and put the user's words into its brief.
- **Cancel**: publish nothing and say so.
- **Publish**: go on to step 7.

Publish only after the user has said yes to the list as it was last shown, in this run. An earlier yes, or a yes to a list that changed since, does not count.

## 7. Publish

The milestone is the one of the given issue. If it has none, take the one of the nearest issue above it that has one. Sub-issues do not inherit it, so set it on every task. If no issue above has one, leave it out.

Create the tasks one at a time, in dependency order, one command per task:

1. Finish the body. Replace every working id in it with `#` and the number of the issue it became, and under "Depends on" add that issue's title. The tasks it depends on were created before it, so their numbers are known. Then search the file for `T-0`. A working id means nothing on GitHub, so none may be left.
2. Create the issue:

   ```
   gh issue create \
     --title '<title>' \
     --body-file <file> \
     --parent <given issue> \
     --type Sub-Task \
     --milestone "<milestone>" \
     --blocked-by <number>,<number>
   ```

   The type is always `Sub-Task`, the issue type this repository keeps for tasks that `/breakdown` publishes. Type the title out in full, in single quotes. Leave out `--blocked-by` for a task that depends on nothing, and `--milestone` when there is none.
3. Read the number of the new issue from the address `gh` prints, and note which working id it stands for.

If a command fails, stop. Do not run it again without knowing whether the issue was created: look at `gh issue view <given issue> --json subIssues` first. Do not delete or close anything. Report which tasks exist and which do not. A later run of `/breakdown` on the same issue finds the ones that exist and plans only the rest.

When all are created, read `gh issue view <given issue> --json subIssues` and check that every task is there.

## 8. Report

One row per task, in the order they were created:

| Issue | Title | Depends on | Agent |
|---|---|---|---|

Then, in a few lines:

- the issue they were published under, with its address, and the milestone they carry;
- which tasks can start now, because they depend on nothing;
- that `/implement <given issue>` carries the tasks out, one at a time in this order;
- anything that could not be published, and why.

## Limits

- Do not publish anything before the user confirms.
- Do not change the given issue or any issue above it: no edit to its text, no comment, no label, no assignee, no change of state.
- Do not add labels to the tasks, and do not set their status on the project board. `critical`, `high`, `medium` and `low` rate pull requests, not issues.
- Do not edit, close or delete a sub-issue that already exists.
- Do not create a branch, change a file of the repository, commit or open a pull request. `/implement` does the work.
