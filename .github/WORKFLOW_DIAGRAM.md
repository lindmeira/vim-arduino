# Automated README Update Workflow - Visual Guide

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Developer Activity                          │
└─────────────────────────────────────────────────────────────────┘
                               │
                               │ git push to master
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub: Push Event                           │
│                                                                 │
│  Changed files:                                                 │
│    ├─ lua/arduino/init.lua                                     │
│    ├─ lua/arduino/config.lua                                   │
│    └─ plugin/arduino.vim                                       │
└─────────────────────────────────────────────────────────────────┘
                               │
                               │ Trigger check
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│              Workflow: update-readme.yml                        │
│                                                                 │
│  ┌──────────────────────────────────────────────────┐          │
│  │ Step 1: Check Trigger Conditions                 │          │
│  │  • Branch = master? ✓                            │          │
│  │  • README.md changed? ✗ (excluded)               │          │
│  │  • Workflow file changed? ✗ (excluded)           │          │
│  └──────────────────────────────────────────────────┘          │
│                               │                                 │
│                               │ Trigger conditions met          │
│                               ▼                                 │
│  ┌──────────────────────────────────────────────────┐          │
│  │ Step 2: Checkout & Setup                         │          │
│  │  • Clone repository                              │          │
│  │  • Setup Node.js 20                              │          │
│  └──────────────────────────────────────────────────┘          │
│                               │                                 │
│                               ▼                                 │
│  ┌──────────────────────────────────────────────────┐          │
│  │ Step 3: Analyze Changed Files                    │          │
│  │  • Get diff: HEAD^ vs HEAD                       │          │
│  │  • Check for code files (.lua, .vim, plugin/*)   │          │
│  │  • Result: CODE_CHANGED = true                   │          │
│  └──────────────────────────────────────────────────┘          │
│                               │                                 │
│                               │ Code changed = true             │
│                               ▼                                 │
│  ┌──────────────────────────────────────────────────┐          │
│  │ Step 4: Generate AI Prompt                       │          │
│  │  • Current README content                        │          │
│  │  • List of changed files                         │          │
│  │  • Git diff of changes                           │          │
│  │  • Instructions for AI                           │          │
│  └──────────────────────────────────────────────────┘          │
│                               │                                 │
│                               ▼                                 │
│  ┌──────────────────────────────────────────────────┐          │
│  │ Step 5: Call Claude AI (Anthropic)               │          │
│  │  • Model: claude-3-5-sonnet-20241022             │          │
│  │  • Max tokens: 4096                              │          │
│  │  • API Key: $ANTHROPIC_API_KEY (secret)          │          │
│  │  • Returns: Updated README markdown              │          │
│  └──────────────────────────────────────────────────┘          │
│                               │                                 │
│                               ▼                                 │
│  ┌──────────────────────────────────────────────────┐          │
│  │ Step 6: Update README File                       │          │
│  │  • Save AI response to README.md                 │          │
│  │  • Stage changes: git add README.md              │          │
│  └──────────────────────────────────────────────────┘          │
│                               │                                 │
│                               ▼                                 │
│  ┌──────────────────────────────────────────────────┐          │
│  │ Step 7: Commit & Push                            │          │
│  │  • Commit message: "docs: auto-update README     │          │
│  │    based on code changes [skip ci]"              │          │
│  │  • Push to origin/master                         │          │
│  └──────────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Repository Updated                             │
│                                                                 │
│  New commit on master:                                          │
│    • Original code changes                                      │
│    • Updated README.md (separate commit)                        │
│                                                                 │
│  [skip ci] prevents infinite loop                              │
└─────────────────────────────────────────────────────────────────┘
```

## Scenario Examples

### Scenario A: Code Change (Triggers Update)

```
Input:
  Files changed: lua/arduino/init.lua, lua/arduino/config.lua
  README changed: No

Flow:
  1. Workflow triggers ✓
  2. Code detected ✓
  3. AI analyzes changes ✓
  4. README updated ✓
  5. Committed with [skip ci] ✓

Output:
  • 2 commits: (1) code changes, (2) README update
```

### Scenario B: README Change (No Update)

```
Input:
  Files changed: README.md
  README changed: Yes

Flow:
  1. Workflow does NOT trigger (paths-ignore)
  
Output:
  • 1 commit: README change only
  • No workflow run
```

### Scenario C: Documentation Change (No Update)

```
Input:
  Files changed: AGENTS.md, doc/arduino.txt
  README changed: No

Flow:
  1. Workflow triggers ✓
  2. Code detected ✗ (docs only)
  3. Workflow exits early
  
Output:
  • 1 commit: doc changes
  • Workflow runs but skips update
```

### Scenario D: Mixed Change (Manual README Takes Precedence)

```
Input:
  Files changed: lua/arduino/init.lua, README.md
  README changed: Yes

Flow:
  1. Workflow triggers (paths-ignore doesn't block mixed commits)
  2. Detects README.md in changed files
  3. Skips automatic update to preserve manual edits
  4. Workflow exits early
  
Output:
  • 1 commit: code + README changes
  • Workflow runs but skips update (manual README preserved)
```

## Decision Tree

```
                    Push to master
                          │
                          ▼
              ┌───────────────────────┐
              │ README.md ONLY in     │
              │ changes?              │
              └───────────────────────┘
                     │           │
                  Yes│           │No (or mixed)
                     │           │
                     ▼           ▼
              ┌──────────┐  ┌────────────────┐
              │SKIP      │  │ Workflow runs  │
              │(paths-   │  │                │
              │ignore)   │  └────────────────┘
              └──────────┘         │
                                   ▼
                          ┌────────────────┐
                          │ README.md in   │
                          │ changed files? │
                          └────────────────┘
                               │        │
                            Yes│        │No
                               │        │
                               ▼        ▼
                        ┌──────────┐  ┌────────────────┐
                        │SKIP      │  │ Code files in  │
                        │(manual   │  │ changes?       │
                        │README)   │  └────────────────┘
                        └──────────┘       │        │
                                        Yes│        │No
                                           │        │
                                           ▼        ▼
                                    ┌──────────┐  ┌──────────┐
                                    │UPDATE    │  │SKIP      │
                                    │README    │  │(no code  │
                                    │with AI   │  │changes)  │
                                    └──────────┘  └──────────┘
```

## Infinite Loop Prevention

### Multiple Safeguards

1. **paths-ignore in workflow**
   ```yaml
   paths-ignore:
     - 'README.md'
     - '.github/workflows/update-readme.yml'
   ```
   Prevents triggering when ONLY README or workflow changes

2. **README.md detection check**
   ```bash
   if grep -qsE '^README\.md$' changed_files.txt; then
     # Skip update to preserve manual edits
   fi
   ```
   Skips automatic update when README.md is in changed files (even in mixed commits)

3. **[skip ci] in commit message**
   ```
   git commit -m "docs: auto-update README ... [skip ci]"
   ```
   Prevents CI/CD from re-running

4. **Code-only detection**
   ```bash
   grep -qE '\.(lua|vim)$|^plugin/|...' changed_files.txt
   ```
   Only processes if actual code changed

### Why This Works

```
Commit with code change
       │
       ▼
Workflow runs → Updates README → Commits with [skip ci]
                                         │
                                         ▼
                                  New commit pushed
                                         │
                                         ▼
                       ┌─────────────────────────────────┐
                       │ Does NOT trigger workflow       │
                       │ Reason 1: paths-ignore (README) │
                       │ Reason 2: [skip ci] tag         │
                       └─────────────────────────────────┘
```

## API Integration

### Claude API Request Flow

```
┌─────────────────────────────────────────────────────────┐
│ Node.js Script (in workflow)                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. Read prompt file (context + changes)               │
│     │                                                   │
│     ▼                                                   │
│  2. Construct API request                              │
│     {                                                   │
│       "model": "claude-3-5-sonnet-20241022",           │
│       "max_tokens": 4096,                              │
│       "messages": [{"role": "user", "content": "..."}] │
│     }                                                   │
│     │                                                   │
│     ▼                                                   │
│  3. HTTPS POST to api.anthropic.com                    │
│     Headers:                                            │
│       - x-api-key: $ANTHROPIC_API_KEY                  │
│       - anthropic-version: 2023-06-01                  │
│     │                                                   │
│     ▼                                                   │
│  4. Receive response                                   │
│     {                                                   │
│       "content": [{"text": "# arduino.nvim\n..."}]     │
│     }                                                   │
│     │                                                   │
│     ▼                                                   │
│  5. Extract updated README markdown                    │
│     │                                                   │
│     ▼                                                   │
│  6. Write to README.md                                 │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Error Handling

```
API Key missing?
    │
    ▼
Exit gracefully (no error)
    │
    └─> Allows manual README updates


API call fails?
    │
    ▼
Log error, exit with code 0
    │
    └─> Workflow completes without update


Invalid response?
    │
    ▼
Log error, exit with code 0
    │
    └─> Workflow completes without update (graceful degrade)
```

## Monitoring & Debugging

### Check Workflow Runs

1. Go to repository → Actions tab
2. Find "Auto-Update README" workflow
3. Click on specific run to see:
   - Which files changed
   - Whether code was detected
   - API call success/failure
   - Commit details

### Common Issues & Solutions

| Issue | Check | Solution |
|-------|-------|----------|
| Workflow doesn't trigger | Branch name | Must be `master` |
| README not updated | API key | Add `ANTHROPIC_API_KEY` secret |
| Infinite loops | Commit messages | Verify `[skip ci]` tag present |
| Wrong files ignored | paths-ignore | Check YAML syntax |
| API quota exceeded | Anthropic console | Add billing/upgrade plan |

## Performance & Cost

### Typical Workflow Run

- **Duration**: 30-60 seconds
- **API Call**: 1 per code change
- **Tokens**: 2,000-4,000 (varies by change size)
- **Cost**: $0.01-0.02 per update

### Optimization Tips

1. **Batch changes**: Multiple commits in PR = 1 README update on merge
2. **Manual updates**: For trivial changes, update README yourself
3. **Draft PRs**: Work in draft mode to avoid premature updates
4. **API model**: Use claude-3-haiku for cheaper updates (less quality)

## Security

### Secret Management

```
GitHub Repository
    │
    └─> Settings
        │
        └─> Secrets and variables
            │
            └─> Actions
                │
                └─> ANTHROPIC_API_KEY (encrypted)
                    │
                    └─> Only accessible to workflows
                        │
                        └─> Never exposed in logs
```

### Permissions

Workflow has minimal permissions:
- ✓ `contents: write` - Required to push README
- ✗ No admin access
- ✗ No secrets access beyond specified
- ✗ No access to other repositories

## Conclusion

This workflow provides a robust, secure, and cost-effective solution for keeping README documentation synchronized with code changes, with multiple safeguards against common issues.
