# Automated README Updates

This repository includes a GitHub Actions workflow that automatically updates the README.md file whenever code changes are pushed to the master branch.

## How It Works

The workflow (`.github/workflows/update-readme.yml`) performs the following steps:

1. **Triggers**: Activates on push to the `master` branch, but ignores changes to:
   - `README.md` itself (to prevent infinite loops)
   - The workflow file itself

2. **Change Detection**: Analyzes the commit to identify changed files, specifically looking for:
   - Lua source files (`.lua`)
   - Vim plugin files (`.vim`)
   - Plugin structure changes (`plugin/`, `ftplugin/`, `ftdetect/`, `syntax/`)

3. **README Update**: If code files changed:
   - Collects the git diff showing what changed
   - Sends the current README and changes to Claude AI (Anthropic)
   - Claude analyzes the changes and updates the README to:
     - Document new features and commands
     - Update obsolete information
     - Refresh examples if APIs changed
     - Maintain existing structure and style

4. **Commit**: Automatically commits and pushes the updated README with the message:
   ```
   docs: auto-update README based on code changes [skip ci]
   ```

## Setup Requirements

### Option 1: Using Anthropic's Claude API (Recommended)

This workflow uses Claude 3.5 Sonnet for intelligent documentation updates.

**Setup Steps:**

1. Get an API key from [Anthropic Console](https://console.anthropic.com/)
2. Add it as a repository secret:
   - Go to your repository Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `ANTHROPIC_API_KEY`
   - Value: Your API key

**Cost Considerations:**
- Claude API calls are metered based on tokens
- Typical README update: ~2,000-4,000 tokens (~$0.01-$0.02 per update)
- Monitor usage at [Anthropic Console](https://console.anthropic.com/)
- Check current pricing at [Anthropic Pricing](https://www.anthropic.com/pricing)

### Option 2: Manual Updates

If you prefer not to use AI or don't want to set up API keys:

1. The workflow will detect code changes but skip the README update silently
2. You can update the README manually when needed
3. Manual updates can be committed normally

## Preventing Infinite Loops

The workflow is designed to prevent infinite loops through multiple safeguards:

1. **Path Exclusion**: `paths-ignore` prevents triggering when ONLY README.md changes
2. **README Detection**: Explicit check skips automatic updates when README.md is in changed files (preserves manual edits even in mixed commits)
3. **Skip CI Tag**: Commits include `[skip ci]` to prevent re-triggering
4. **Code Change Detection**: README updates only run when actual code files change (the workflow may still run for other pushes and exit without updating the README)

## Customization

### Modifying the AI Prompt

Edit the prompt in `.github/workflows/update-readme.yml` at the "Generate README update prompt" step to:
- Change the documentation style
- Add specific instructions
- Focus on particular aspects of changes

### Changing the AI Model

To use a different Claude model, modify the `model` parameter in the Node.js script:
```javascript
model: "claude-3-5-sonnet-20241022",  // Change this
```

Available models:
- `claude-3-5-sonnet-20241022` (recommended, balanced)
- `claude-3-opus-20240229` (highest quality, slower, more expensive)
- `claude-3-haiku-20240307` (faster, cheaper, good for simple updates)

**Note:** Model versions may be updated or deprecated over time. Check [Anthropic's documentation](https://docs.anthropic.com/claude/docs/models-overview) for the latest available models.

### Using a Different AI Provider

To use OpenAI, Gemini, or another provider:
1. Modify the Node.js script in the workflow
2. Update the API endpoint and authentication
3. Adjust the request/response format accordingly
4. Update the secret name in repository settings

## Testing the Workflow

To test the workflow:

1. Make a small change to a Lua file in the `lua/arduino/` directory
2. Commit and push to master
3. Check the Actions tab in GitHub to see the workflow run
4. Verify that the README.md is updated (if API key is configured)

## Troubleshooting

### Workflow doesn't trigger
- Check that you're pushing to the `master` branch
- Verify that code files (not just README.md) were changed
- Check the Actions tab for any errors

### README not updated
- Verify the `ANTHROPIC_API_KEY` secret is set correctly
- Check the workflow logs in the Actions tab
- Ensure your API key has sufficient credits

### Infinite loop detected
- Check that the commit message includes `[skip ci]`
- Verify the `paths-ignore` configuration is correct
- Check git history for repeated commits

## Manual Override

If you need to update the README without code changes:
1. Edit README.md directly
2. Commit with message: `docs: manual README update [skip ci]`
3. Push to master

The `[skip ci]` tag ensures the workflow doesn't try to "update" your manual changes.

## Benefits

- **Consistency**: README stays in sync with code
- **Time-Saving**: No manual documentation updates for every code change
- **Quality**: AI analysis ensures comprehensive coverage of changes
- **History**: Git history tracks both code and documentation evolution together

## Limitations

- Requires API key and internet connectivity
- AI may occasionally misinterpret complex changes
- Works best with well-structured, commented code
- May need manual review for major refactorings

## Contributing

If you improve this workflow, please update this documentation to reflect:
- New configuration options
- Alternative AI providers
- Enhanced prompting strategies
- Additional safeguards or features
