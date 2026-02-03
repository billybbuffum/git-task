# git-task

A git workflow manager that uses copy-on-write clones for instant, space-efficient workspaces.

## Why?

When working on multiple features or reviewing PRs, you often need separate working directories. Traditional approaches (`git worktree`, multiple clones) have tradeoffs:

- **git worktree**: Shared object store but awkward path management, IDE confusion
- **Multiple clones**: Full disk usage for each copy, slow to create

**git-task** creates instant clones using filesystem copy-on-write (APFS on macOS, reflink on Linux). Each task is a complete, independent git repo that only uses disk space for files you actually change.

## Why not just use git worktree?

git-task is not trying to replace `git worktree` for standard human-driven Git workflows.
It exists because `git worktree` breaks down under a specific set of constraints that are increasingly common in agent-heavy, tooling-heavy, large-repo environments.

**If none of the following apply to you, you should probably just use `git worktree`.**

### The problem space git-task targets

#### 1. Massive repositories

In very large repos, creating multiple working directories is expensive:

- `git worktree` shares Git objects, but fully materializes the working tree
- Creating or switching worktrees can be slow and IO-heavy
- Disk usage grows linearly with each worktree

git-task uses copy-on-write (CoW) filesystem clones where supported (APFS, reflinks), meaning:

- New tasks are created nearly instantly
- Unchanged files are physically shared
- Disk and IO costs scale with actual changes, not repo size

#### 2. Parallel, isolated work (especially with agents)

If you are running:

- Multiple LLM agents
- Short-lived experimental branches
- Parallel automated workflows

You need:

- Independent working directories
- Independent uncommitted state
- No file-level contention
- Fast spin-up and teardown

While `git worktree` provides isolation, it assumes long-lived, manually managed directories.
git-task is optimized for cheap, disposable, parallel environments.

#### 3. Tooling that assumes a single, stable repo path

Many tools implicitly assume:

- One canonical repo root
- Stable paths for caches, configs, IDEs, scripts, and build systems
- That "the repo" does not move

With `git worktree`:

- Every worktree lives at a different path
- Tooling often needs to be reconfigured or duplicated
- IDEs and scripts frequently break or become awkward

git-task keeps one stable repo path and switches tasks by changing what that path points to (via symlinks), so:

- IDEs don't need reconfiguration
- Scripts keep working
- Tooling sees "the same repo" even as tasks change

### How git-task is different from git worktree

| Aspect | git worktree | git-task |
|--------|--------------|----------|
| Working directory | One per worktree | One logical path, many tasks |
| Path stability | Changes per worktree | Always stable |
| Disk usage | Full working tree per worktree | CoW / shared until modified |
| Spin-up cost | Moderate to high (large repos) | Near-instant (CoW FS) |
| Agent ergonomics | Manual, directory-aware | Agent-friendly, disposable |
| Git-native | Yes | Uses Git + filesystem primitives |

### When you should use git worktree

- You want a standard, well-known Git workflow
- You have a small-to-medium repo
- You manually switch branches occasionally
- You don't rely on tooling that assumes a single repo location

### When git-task makes sense

- You have a very large repo
- You run many parallel tasks or agents
- Your tooling assumes one stable repo path
- You value throughput and ergonomics over convention
- You're comfortable with a sharper, more opinionated tool

### Design philosophy

git-task is intentionally opinionated.

It optimizes for:

- Local developer throughput
- Parallel experimentation
- Agent-first workflows
- Filesystem efficiency

It trades off:

- Strict Git orthodoxy
- Cross-filesystem portability
- Team-wide default safety

**This is a power tool. Use it when the constraints justify it.**

## Installation

```bash
# Clone and add to PATH
git clone https://github.com/youruser/git-task.git
export PATH="$PATH:$(pwd)/git-task"

# Or copy directly to a bin directory
cp git-task/git-task /usr/local/bin/
```

## Quick Start

```bash
# Initialize in your repo
cd my-project
git task init

# Create a task for a feature
git task new auth-refactor

# Switch to it (updates the symlink your IDE follows)
git task switch auth-refactor

# Make changes, commit as usual
git add . && git commit -m "refactor auth"

# Push the task's branch
git task push

# List all tasks
git task list

# Clean up when done
git task destroy auth-refactor
```

## How It Works

```
Before init:
  ~/projects/my-app/          # Your repo

After init:
  ~/projects/my-app/          # Symlink → my-app-tasks/main
  ~/projects/my-app-tasks/
    ├── main/                 # Original repo state
    ├── auth-refactor/        # CoW clone, branch: task/auth-refactor
    └── fix-bug-123/          # CoW clone, branch: task/fix-bug-123
```

The symlink at your original path means:
- Your IDE keeps working without reconfiguration
- Terminal sessions stay in the "same" directory
- Switching tasks is instant (just updating a symlink)

Each task directory is a full git repo with its own branch, so you can:
- Have different uncommitted changes in each task
- Run builds/tests in parallel across tasks
- Work on one task while another runs a long process

## Commands

| Command | Description |
|---------|-------------|
| `git task init` | Initialize git-task for current repo |
| `git task new <name> [base]` | Create new task (optionally from another task) |
| `git task switch <name>` | Switch active task (update symlink) |
| `git task list` | List all tasks with branch and status |
| `git task status` | Show git-task configuration and disk usage |
| `git task destroy <name>` | Remove a task (checks for uncommitted work) |
| `git task push` | Push current task's branch |
| `git task path [name]` | Print path to task directory |
| `git task exec <name> <cmd>` | Run command in a task's directory |

## Usage Patterns

### Feature Development

```bash
git task new feature-x
git task switch feature-x
# ... develop ...
git task push
# Create PR, get it merged
git task destroy feature-x
```

### PR Review

```bash
git task new review-pr-456
git task switch review-pr-456
git fetch origin pull/456/head:pr-456
git checkout pr-456
# ... review, test ...
git task destroy review-pr-456 --force
```

### Parallel Agent Workflows

Run multiple AI coding agents simultaneously, each in their own task:

```bash
git task new agent-auth
git task new agent-api
git task new agent-ui

# Run agents in parallel (each gets isolated workspace)
git task exec agent-auth claude "implement auth system" &
git task exec agent-api claude "build REST API" &
git task exec agent-ui claude "create dashboard UI" &
wait
```

### Quick Experiments

```bash
git task new experiment
git task switch experiment
# ... try something risky ...
git task destroy experiment --force  # Didn't work? Gone instantly
```

## Disk Usage

Copy-on-write means tasks start using almost zero additional space. You only pay for:
- Files you modify (the changed version is stored)
- New files you create

Check usage with:
```bash
git task status
```

## Platform Support

| Platform | Clone Method | Notes |
|----------|--------------|-------|
| macOS (APFS) | `cp -Rc` | Native CoW, instant clones |
| Linux (btrfs/xfs) | `cp --reflink=auto` | CoW if filesystem supports it |
| Linux (ext4/other) | `cp -R` | Falls back to regular copy |

## Limitations

- Requires the repo's parent directory to be writable (for the `-tasks` directory)
- The original repo path becomes a symlink (some tools may not follow symlinks)
- Each task has independent git state (remotes, config) - changes to one don't affect others

## License

MIT
