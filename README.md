# NoTSUG-2026-SAS-AI
North Texas SAS User Group - SAS - AI

## Example project: Ad-Frequency Perception (SAS Studio + Claude)

This repo includes a scaffolded SAS Studio project (`sas/`) demonstrating a
task SAS has no native procedure for: turning open-ended, natural-language
survey answers into a quantified frequency judgment, using Claude as the
"reasoning" engine and comparing multiple Claude models against each other.

**Workflow:** a fake marketing questionnaire asks respondents "How often
does this advertisement appeal to you?" and captures free-text answers like
*"every once in a while it catches my eye"* or *"it appeals to me every
single time."* PROC FREQ can't interpret language like that - Claude can.
Each response is sent to several Claude engines, which return a classified
frequency bucket (Never/Rarely/Sometimes/Often/Always) plus their own
reliability/confidence score. Because the fake data also carries a hidden
"true" bucket, the project can then score each engine's accuracy and check
whether its confidence is well-calibrated.

### Folder structure
```
sas/
  00_setup/               Project config: paths, API key, engine list
  01_generate_fake_data/  Generates the fake survey dataset
  02_call_claude/         Prompt template + PROC HTTP calls to Claude, per engine
  03_analyze_results/     Accuracy, confusion matrix, and reliability calibration
  99_utils/                Shared macros and a JSON-field extraction helper
  run_all.sas              Runs the full pipeline end to end
```

### Running it in SAS Studio
1. Open the `sas/` folder as your SAS Studio project (or copy it into your
   SAS Studio "Files" area).
2. Set an environment variable `ANTHROPIC_API_KEY` with your Anthropic API
   key (SAS Studio → Manage Environment Variables, or your Compute Server's
   environment) - the code never hard-codes secrets.
3. Update the model IDs in `00_setup/config.sas` (`proj.claude_engines`) to
   match models your API key can access.
4. Run `sas/run_all.sas`, or step through `00_setup` → `01_generate_fake_data`
   → `02_call_claude` → `03_analyze_results` individually.

Outbound HTTPS access to `api.anthropic.com` is required for step 2.
