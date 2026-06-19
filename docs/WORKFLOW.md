# Development Workflow - fern 🌿

To maintain code quality and stability, every new feature or bug fix must follow this strict process.

### Step 1: Preparation

1. Pick a task from `ROADMAP.md`.
2. Create a new branch: `git checkout -b feature/task-name` or `bugfix/bug-name`.

### Step 2: Development (AI/TDD Method)

1. **Provide Context:** Open your editor (whether you are working in Xcode for the Apple UI or configuring the Rust core in Neovim), and, if you use it, provide the AI with the `docs/CONTEXT.md` file along with the specific files you want to modify.
2. **Test First:** Ask the AI (or write it yourself) to create the unit test describing the expected outcome _before_ writing the implementation.
3. **Write Implementation:** Code the function to make the test pass (verify via `cargo test`).
4. **Refactor:** Clean up the code and resolve all linter warnings (`cargo clippy`).

### Step 3: Validation

1. Run the full test suite locally.
2. Format the code: `cargo fmt`.

### Step 4: Commit & Pull Request

1. Commit using the conventional format: `feat(core): add time calculation logic`.
2. Update the `ROADMAP.md` (check the box) and the `CHANGELOG.md` (add the line under `[Unreleased]`).
3. Merge the branch into `main`.
