# Repo-Backed Operations

Chat history and individual workstations are poor sources of operational truth.
A Git repository can carry the durable institution instead:

- architecture and recovery runbooks;
- host or role-specific operating instructions;
- configuration and automation;
- incident findings and validation evidence;
- active handoffs for concurrent workers;
- policy tests and safety checks.

This model works for human teams and for interchangeable AI coding agents. The
worker may change; the repository remains reviewable, portable, and recoverable.

## Recommended Layout

```text
docs/                 architecture and runbooks
hosts/<role>/         role-specific state and instructions
handoffs/             active coordination notes
scripts/              reusable automation
tests/                executable policy and regression checks
examples/             deployment-neutral reference configuration
```

Use roles rather than personal tool names. A future worker should not need the
same editor, model, or operating system to understand the record.

## Operating Contract

1. Resolve the execution host and role before writing durable state.
2. Read the subsystem runbook before changing an already configured system.
3. Keep secrets out of Git; document retrieval contracts, not values.
4. Preserve unrelated dirty work and stage only scoped files.
5. Validate the end state before recording it as complete.
6. Commit durable findings so another worker can continue.
7. Keep destructive capabilities behind mechanisms stronger than instructions.

## Enforced and Judgment Rules

Separate rules by whether they can be enforced mechanically:

| Type | Examples | Treatment |
| --- | --- | --- |
| Enforced | secret scanning, protected paths, write scopes, branch protection | Make the unsafe action fail |
| Judgment | naming, prose quality, preferred troubleshooting order | Keep reversible and reviewable |

Catastrophic outcomes should not depend only on a worker remembering a written
rule. Use hooks, permissions, scoped credentials, protected environments, and
validation workflows where the consequence is irreversible.

## Coordination

Concurrent workers should use isolated branches or worktrees. Before editing a
shared conflict point, create a short active handoff naming the files and
subsystem. Clear it after the scoped change is reconciled.

Never use broad staging or cleanup in a shared dirty checkout. Exact paths make
ownership visible and reduce accidental cross-task changes.

## Validation Before Record

A completion note is not evidence. Useful evidence includes:

- parser or syntax checks;
- unit and integration tests;
- post-change service state;
- browser or client-path verification;
- before-and-after output;
- a clean staged diff and leak scan.

The repository should explain not only what changed, but how the claimed result
was proven.
