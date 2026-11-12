# sw-qa

Software QA for AI coding agents. When you ask whether something works, the agent runs a QA pass instead of reading the code and saying it looks fine.

Ask "QA 진행해줘", "제대로 동작하는지 테스트해줘" or "check that this works", and the `qa` skill has the agent:

1. **Find what to test** from the repository itself: the commit history (what changed, what broke before), the CI pipeline (what is checked automatically, and what is not), the code (entry points, inputs, error branches) and the existing tests.
2. **Define QA items per feature**, each with a named oracle: stated intent (documents, help text, schemas, commit messages), the base revision, an invariant, or the implicit oracle (no crash, no data loss). Expected results are never copied from the output of the code under test.
3. **Design cases in two layers**: standard QA (smoke, functional, negative and boundary, error handling, regression, integration, static checks, security basics, configuration, data integrity, documentation) and checks specific to the feature type and the domain, from the bundled checklists (pagination, uploads, sessions, money, migrations, queues, pipelines, model serving, streaming, alerting and more).
4. **Execute the cases** against the running software, recording the input and the observed output of each one.
5. **Measure test adequacy** with [mutation-gate](https://github.com/godic97/mutation-gate) when it is installed, and check each surviving mutant by hand.
6. **Triage every failure** as a product defect, a pre-existing failure, a stale test, an environment problem or a question for the owner.
7. **Report** a GO / NO-GO / CONDITIONAL verdict, the defects with reproduction steps, the test gaps, and what was not verified and why.

A case that was not executed is never reported as passed, and the QA pass changes nothing in your repository or your data: it reports, and you decide.

sw-qa is part of [Gingoa](https://github.com/godic97/Gingoa).

## Install

The skill follows the open [Agent Skills](https://agentskills.io) format, so the same `skills/qa/` directory works in every agent that supports skills.

**Claude Code**

```
claude plugin marketplace add godic97/sw-qa
claude plugin install sw-qa@sw-qa
```

Inside Claude Code, the same works as `/plugin marketplace add …` followed by `/plugin install …`.

**OpenAI Codex** (CLI and desktop app)

```
codex plugin marketplace add godic97/sw-qa
codex plugin add sw-qa@sw-qa
```

Start a new session afterwards. For the IDE extension or Codex cloud, copy `skills/qa` to `~/.agents/skills/qa` or to `.agents/skills/qa` in your project.

**GitHub Copilot CLI**

```
copilot plugin install godic97/sw-qa
```

**Any other agent** (Cursor, Gemini CLI, OpenCode, Cline, Windsurf/Devin, Kiro, Amp, Goose, Pi, Antigravity, ...), with either installer:

```
npx skills add godic97/sw-qa
gh skill install godic97/sw-qa qa --agent <agent> --scope user
```

`npx skills` asks which agents to install into; `gh skill` needs GitHub CLI 2.90 or later. Or copy `skills/qa` into the agent's skills directory (`~/.agents/skills/` is read by most of them).

The Claude Code and Codex routes were tried on this layout; the others follow each agent's documentation and have not been run.

## Usage

Ask in your own words. The skill also triggers on requests to regression-test a change, check a fix, decide whether a branch is safe to ship, or design test cases. It stays out of neighbouring requests: running one named test command, writing unit tests, explaining a failing test, or reviewing a diff without running anything.

| Ask for | You get |
|---|---|
| A QA pass ("QA 진행해줘", "is this safe to ship?") | The full pass and report. The target is what you name (a branch, a pull request, a path, a feature); otherwise the current branch's changes and uncommitted work, else the last commit |
| Test design only ("테스트 케이스만 뽑아줘", "design the test cases") | The feature inventory and the case table |
| A bug report ("버그 리포트 써줘") | A defect report for a failure you already saw |

To call it explicitly: `/sw-qa:qa` in Claude Code, `$qa` in Codex, `/qa` in most other agents.

## With the other Gingoa plugins

Both are Claude Code plugins. The skill works without them and says so in the report.

- **[mutation-gate](https://github.com/godic97/mutation-gate)**: the QA pass runs `mutation-gate test` on the source of the highest-priority features (LLM mode when the language's tool is not installed), quotes the summary line, and checks each surviving mutant with a QA case. It only measures: during QA it does not add tests, install tools or accept mutants.
- **[claim-check](https://github.com/godic97/claim-check)**: the report states each automated result once, with its command, in a form claim-check can match against the transcript, and calls hand-executed cases "QA cases", not "tests".

## Limits

- sw-qa is a skill: instructions the agent follows, not a check enforced by the harness. It makes a QA pass systematic and its report honest about gaps; it does not prove the pass was complete.
- QA covers what can run where the agent runs. Cases that need production data, hardware or an external service are reported as blocked, or run against a local stub and marked `(stub)`.
- Expected results come from what the repository states. Behaviour that nothing documents is run, marked `(inferred)`, and listed as an open question.
- The checklists cover common domains and feature types; for others the agent derives the cases itself.
- Depth follows risk: the changed and highest-risk features get the full set of checks, the rest their main path, and the report lists which got the main path only.

## Development

The eval suite under `evals/` runs with `claude plugin eval`:

- `evals/trigger/`: 40 Korean and English prompts, 20 that should trigger the skill and 20 near misses that should not.
- `evals/behaviour/`: four small repositories (a pricing CLI, a notes HTTP API, a sensor ETL job, an alert filter) with planted defects that are found from the documents, the commit history, CI gaps and the code, plus correct behaviour that looks suspicious and parts that need an external service. Each run is scored with and without the skill.

```
claude plugin validate .
claude plugin eval . --tag trigger --ablation none --no-publish
claude plugin eval . --tag behaviour --scaffold --allow-tools Bash --no-publish
```

## License

MIT. See [LICENSE](LICENSE).
