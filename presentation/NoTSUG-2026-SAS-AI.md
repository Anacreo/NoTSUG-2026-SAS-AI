---
marp: true
theme: default
paginate: true
title: SAS + AI - Calling Claude from SAS, Comparing Engine Cost, GitHub to SAS Studio
---

# SAS + AI
## Calling an LLM from SAS, comparing engines and cost, and building SAS code in GitHub

North Texas SAS User Group (NoTSUG) 2026
Repo: github.com/Anacreo/NoTSUG-2026-SAS-AI

---

# Agenda
1. The problem: free text SAS can't quantify
2. Project structure (`sas/`)
3. Calling the LLM with `PROC HTTP`
4. Parsing responses
5. Comparing engines: accuracy, calibration, **cost**
6. GitHub building the code and feeding SAS Studio
7. Lessons and Q&A

*Every slide shows code exactly as it exists in the repo.*

---

# The problem
Survey question: *"How often does this advertisement appeal to you?"*

- "every once in a while it catches my eye"
- "it appeals to me every single time"

`PROC FREQ` counts values; it can't read language.

**Goal:** have Claude classify each answer into Never / Rarely / Sometimes / Often / Always, plus its own `reliability_score` (0-1).

---

# Why this test is measurable
`01_generate_fake_data/generate_survey_data.sas`

- Fake respondents drawn from a hidden `true_bucket`
- Multiple natural-language phrasings per bucket
- Output: `proj.survey_responses`

So we can score every engine's **accuracy** and check whether its **confidence is calibrated**.

---

# Project layout
```
sas/
  00_setup/               config.sas (paths, key, engine list)
  01_generate_fake_data/  generate_survey_data.sas
  02_call_claude/         prompt template + PROC HTTP calls
  03_analyze_results/     accuracy, per-question, cost, stats
  99_utils/               macros.sas, extract_json.sas
  run_all.sas             full pipeline driver
```

---

# Pipeline (`run_all.sas`)
```sas
%include "&code_root.00_setup/config.sas";
%include "&code_root.01_generate_fake_data/generate_survey_data.sas";
%include "&code_root.02_call_claude/01_prepare_requests.sas";
%include "&code_root.02_call_claude/02_run_requests.sas";
%include "&code_root.02_call_claude/03_parse_requests.sas";
%include "&code_root.03_analyze_results/01_compare_engines.sas";
%include "&code_root.03_analyze_results/02_question_by_engine.sas";
%include "&code_root.03_analyze_results/03_cost_by_request.sas";
%include "&code_root.03_analyze_results/04_statistical_tests.sas";
```
Prepare, run, and parse are separate so each stage can be inspected and rerun.

---

# Secrets (`config.sas`)
- Key read from an external key file (path set in `autoexec.sas`)
- Falls back to the `ANTHROPIC_API_KEY` environment variable
- Never hard-coded
```sas
%let anthropic_api_url     = https://api.anthropic.com/v1/messages;
%let anthropic_api_version = 2023-06-01;
```

---

# Engines compared (`config.sas`)
```sas
data proj.claude_engines;
  ...
  datalines;
claude-haiku-4-5-20251001 Claude Haiku 4.5 (fast, low cost)
claude-sonnet-5           Claude Sonnet 5 (balanced)
claude-opus-5-5           Claude Opus 5.5 (highest capability)
;
```
Add an engine = add one row.
`00_list_models.sas` calls `GET /v1/models` to verify IDs your key can access.

---

# The prompt (`claude_prompt_template.sas`)
- Prompt lives in its own file: tune and version it without touching API code
- Role: careful market research analyst
- Classify into exactly one of five buckets
- Return `reliability_score` 0-1
- Respond with ONLY a single-line flat JSON object:
`{"decision": "...", "reliability_score": ...}`

---

# Step 1: build the request queue (`01_prepare_requests.sas`)
```sas
create table proj.claude_requests as
select monotonic() as request_id, e.engine_id, ...
       'PENDING' as status, ...
from proj.claude_engines as e,
     proj.survey_responses(obs=&max_responses.) as s;
```
- Cross join: every response x every engine
- Queue is a SAS table: inspect it before spending money

---

# Step 2: the API call (`02_run_requests.sas`)
```sas
proc http method='POST' url="&anthropic_api_url."
  in=reqbody out=resp;
  headers
    'x-api-key'="&anthropic_api_key."
    'anthropic-version'="&anthropic_api_version."
    'content-type'='application/json';
run;
%let http_status=&SYS_PROCHTTP_STATUS_CODE.;
```
- Body built in a `data _null_` step, JSON-escaped (backslash first, then quotes, then newlines)
- Survey text stays in data rows, **not macro parameters**, so commas/quotes/ampersands can't break macro parsing

---

# Bounded, restartable batches
- `batch_size = 200`, `claude_max_tokens = 500`
- Selects only `status='PENDING'`
- Each request logged to `proj.claude_http_log`
- Queue row updated: `RECEIVED` or `ERROR`, with `http_status`, `raw_response`, `completed_at`
- Rerun to continue where you left off

---

# Step 3: parse (`03_parse_requests.sas`)
- Only `RECEIVED` rows are parsed
- `PRXPARSE` pulls the model's text out of the response envelope
- `json_field()` (FCMP in `99_utils/extract_json.sas`) extracts `decision` and `reliability_score`
- Bad output becomes `PARSE_ERROR`, never a misleading result
- HTTP errors stay visible in `proj.claude_requests`

---

# Comparing engines: accuracy
`03_analyze_results/01_compare_engines.sas`

- Scores each engine's decision vs. hidden `true_bucket`
- Ordinal rank format (`bucket_rank`): Often vs Always is a smaller miss than Never vs Always
- Does the self-reported `reliability_score` track real accuracy?
- Output: `proj.engine_scorecard`, reports, accuracy vs. avg reliability bar chart

`02_question_by_engine.sas`: one row per question, each engine's answer side by side.

---

# Statistical rigor (`04_statistical_tests.sas`)
1. Cochran's Q: paired differences in accuracy across engines
2. Brier score: calibration of stated confidence
3. Reliability bins: stated confidence vs. observed accuracy
4. `PROC FREQ AGREE`: weighted kappa for ordinal agreement

Outputs: `proj.brier_scorecard`, `proj.reliability_bins`, `proj.cochran_q_result`

---

# Costing: what the API returns
`03_cost_by_request.sas`

- The API returns **tokens, not dollars**
- Every response has a `usage` block: `input_tokens`, `output_tokens`, cache token fields
- Extracted with the same `json_field()` helper
- Cost = tokens x price per million tokens

---

# Costing: editable price table
```sas
data proj.model_pricing;
  ...
claude-haiku-4-5-20251001 1  5
claude-sonnet-5           2  10
claude-opus-5-5           4  20
;
```
$ per 1,000,000 tokens (input, output). Per the code comments: checked 2026-09-29, re-verify before budgeting; estimate only (cache and batch pricing not modeled).

---

# Costing: the math in SAS
```sas
(u.billable_input_tokens  * p.input_price_per_mtok  / 1000000) as input_cost,
(u.billable_output_tokens * p.output_price_per_mtok / 1000000) as output_cost,
calculated input_cost + calculated output_cost as est_cost_usd
```
Outputs:
- `proj.claude_request_cost` (one row per request)
- `proj.engine_cost_summary` (total and average per engine)
- Review report for rows missing usage or pricing

---

# Putting cost and accuracy together
| Engine | Accuracy | Calibration | Est. cost |
|---|---|---|---|
| Haiku 4.5 | *from engine_scorecard* | *Brier* | *engine_cost_summary* |
| Sonnet 5 | | | |
| Opus 5.5 | | | |

Live results from the demo run fill this in. The question: is the extra cost of a bigger engine buying accuracy on *this* task?

---

# GitHub builds the SAS code
- All SAS lives in the repo; GitHub Copilot agent branches/PRs built the scaffold, run_all fixes, and model updates
- Branches seen in this repo: scaffolding, `update-run-all-sas`, `research-sas-code-warning`, `updates-from-sas-studio`
- PR = review gate for AI-generated code; history = audit trail

---

# GitHub feeds SAS Studio
- Open the `sas/` folder as a SAS Studio project (or copy to Files)
- Set `ANTHROPIC_API_KEY` or key file in `autoexec.sas`
- Run `run_all.sas`
- Edits made in SAS Studio flow back to GitHub (see the `updates-from-sas-studio` branch)

Requires outbound HTTPS to `api.anthropic.com`.

---

# Lessons from the code
- Keep the prompt in its own file
- Split queue / execute / parse
- Keep text in data, not macro variables
- Fail visibly: `PARSE_ERROR`, `ERROR` status, missing-usage report
- Models get retired (`model_update_note.sas`): keep the engine list in a table
- Never commit keys

---

# Demo
1. `config.sas`: engines and key
2. `01_prepare_requests.sas` then `02_run_requests.sas`
3. `03_parse_requests.sas`
4. Scorecard, per-question view, cost summary

# Questions?
