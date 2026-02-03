# git-task

git-task is an agent-first Git workflow tool for working on many tasks in parallel without duplicating your repository, breaking local tooling, or juggling paths.

It creates isolated task workspaces using filesystem copy-on-write (CoW) cloning where available, while keeping a single stable repo path for your tools and editors.

If you are well served by git worktree, you should probably use that instead.

---

## What problem does this solve?

git-task exists for a narrow but real set of constraints:
- Very large repositories that are expensive to materialize repeatedly
- Parallel work (LLM agents, experiments, automation, throwaway branches)
- Local tooling that assumes one stable repo root
- A need for fast spin-up and teardown of isolated working states

This tool optimizes for throughput under concurrency, not for general Git orthodoxy.

---

## How it works (high level)

- Each task is an isolated working directory backed by its own Git branch
- Tasks are created using copy-on-write filesystem cloning when supported
- The original repo path becomes a symlink pointing at the active task
- Switching tasks updates the symlink, not your tooling configuration

From your tools' perspective, "the repo" never moves.

---

## Example workflow

```bash
git task new feature-x
git task new experiment-y

git task switch feature-x
# work normally

git task switch experiment-y
# independent working state, same repo path
```

Each task:
- Has its own uncommitted changes
- Has its own branch
- Does not interfere with other tasks

---

## Why not just use git worktree?

git worktree is excellent for standard Git workflows.
git-task exists because worktrees break down under certain constraints.

### Key differences

| Aspect | git worktree | git-task |
|--------|--------------|----------|
| Repo path | Changes per worktree | Always stable |
| Working dirs | Fully materialized | CoW when supported |
| Disk usage | One full tree per worktree | Shared until modified |
| Spin-up cost (large repos) | Moderate to high | Near-instant |
| Agent ergonomics | Manual, path-aware | Agent-friendly |
| Git-native | Yes | Git + filesystem primitives |

If you don't need path stability or cheap parallel sandboxes, worktrees are simpler and more portable.

---

## Filesystem support (important)

git-task relies on filesystem reflinks / copy-on-write for its biggest benefits.

### Fully supported (recommended)
- macOS (APFS) ✅
- Linux Btrfs ✅
- Linux XFS (must be created with reflink=1) ✅

On these filesystems:
- Task creation is nearly instant
- Disk usage grows only with actual changes

### ext4 and other non-CoW filesystems
- Tasks fall back to full directory copies
- Disk usage grows linearly with each task
- Task creation time scales with repo size

git-task will still function correctly, but performance and disk benefits are lost.
On ext4, git worktree may be a better choice.

---

## Environment checks

git-task automatically checks for reflink support at runtime.

If your filesystem does not support copy-on-write cloning, you will see a warning and the tool will fall back to full copies.

You can manually verify reflink support:

```bash
cp --reflink=always README.md test-copy
```

If this fails, your filesystem does not support CoW cloning.

---

## Linux / Ubuntu notes

On Ubuntu, filesystem choice matters more than the OS:

| Filesystem | Behavior |
|------------|----------|
| Btrfs | Ideal |
| XFS (reflink=1) | Ideal |
| ext4 | Functional, but slow |
| Other | Depends on reflink support |

---

## Limitations

- The repo root becomes a symlink
- Some tools may not follow symlinks correctly
- This can affect IDEs, file watchers, Docker mounts, or build systems
- Filesystem support varies by platform
- This is an opinionated, power-user tool — not a team-wide default

If symlinks or filesystem constraints are a problem for your setup, this tool may not be a good fit.

---

## When this tool makes sense

Use git-task if:
- You have a large repository
- You run many parallel tasks or agents
- Your tooling assumes one canonical repo path
- You value fast, disposable workspaces
- You are comfortable with sharper tools

Otherwise, use git worktree.

---

## Design philosophy

git-task is intentionally opinionated.

It optimizes for:
- Local developer throughput
- Parallel experimentation
- Agent-first workflows
- Filesystem efficiency

It trades off:
- Universal portability
- Strict Git orthodoxy
- Team-wide safety defaults

This is a power tool. Use it when the constraints justify it.

---

## License

MIT
