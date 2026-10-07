---
marp: true
theme: default
paginate: true
title: SAS + AI - LLMs from SAS, Engine Costs, and GitHub-to-SAS Studio
---

# SAS + AI
## Calling LLMs from SAS, comparing engine costs, and shipping code from GitHub to SAS Studio

North Texas SAS User Group (NoTSUG) 2026

---

# Agenda
1. Why LLMs inside SAS
2. Calling an LLM API with PROC HTTP
3. Parsing responses (JSON libname)
4. Comparing engines and costing
5. GitHub as the build pipeline for SAS code
6. Feeding SAS Studio
7. Governance, security, pitfalls
8. Demo and Q&A

---

# Why LLMs inside SAS?
- Generate / explain / document SAS code
- Classify and summarize text data in-place
- Keep data, logs and results inside existing SAS workflows
- No new platform: just HTTPS + JSON

---

# Architecture
```
SAS Studio  --PROC HTTP-->  LLM API (OpenAI / Anthropic / Gemini / ...)
    ^                              |
    | %include / git pull          v
 GitHub repo  <--- Copilot / PR ---  generated SAS code
```

---

# Part 1: The API call from SAS
- Build JSON request body in a temp fileref
- `PROC HTTP` with `method="POST"`, `in=`, `out=`
- Headers: `Authorization`, `Content-Type`
- Check `&SYS_PROCHTTP_STATUS_CODE`
- Code: `sas/01_llm_call.sas`

---

# Request example
```sas
proc http url="https://api.openai.com/v1/chat/completions"
          method="POST" in=req out=resp;
  headers "Authorization"="******"
          "Content-Type"="application/json";
run;
```
- `temperature=0` for repeatable code generation
- Key from environment variable, never in code or logs

---

# Parsing the response
```sas
libname r json fileref=resp;
proc datasets lib=r; quit;   /* explore tables */
```
- Tables: `choices_message`, `usage`
- `usage` gives prompt and completion tokens: the basis for costing
- Log tokens per call to a SAS dataset for audit

---

# Practical tips
- Use `%macro llm(prompt=, model=)` wrapper; one place to change engines
- Escape quotes/newlines in prompts (`tranwrd`, or JSON functions in `proc json`)
- Retry on 429/5xx with back-off
- Review generated code before `%include`: never auto-execute

---

# Part 2: Comparing engines
Same prompt set, same SAS wrapper, different `model` / endpoint

| Criteria | What to measure |
|---|---|
| Cost | $ per call, $ per month |
| Quality | Does code run? Correct output? |
| Latency | Seconds per call |
| Limits | Context window, rate limits |
| Data policy | Retention, region, enterprise terms |

---

# Costing method
Cost per call = (input tokens x input price + output tokens x output price) / 1,000,000

- Prices are per million tokens, billed separately for input and output
- Output tokens typically cost several times more than input
- Capture real token counts from the `usage` table
- Code: `sas/02_cost_compare.sas`

---

# Example cost comparison (illustrative)
1,200 input / 600 output tokens, 5,000 calls per month

| Engine | Cost per call | Monthly |
|---|---|---|
| Gemini Flash-class | ~$0.0004 | ~$2 |
| GPT-4o-mini-class | ~$0.0005 | ~$2.70 |
| Claude Haiku-class | ~$0.0034 | ~$17 |
| GPT-4o-class | ~$0.0090 | ~$45 |
| Claude Sonnet-class | ~$0.0126 | ~$63 |

**Placeholder prices: verify current vendor pricing before presenting.**

---

# Cost levers
- Smaller model for simple tasks, bigger model for hard ones (routing)
- Trim prompt / context; send only needed columns and code
- Prompt caching and batch APIs discounts
- Cap `max_tokens`
- Cache identical prompts in a SAS dataset

---

# Beyond price: cost of being wrong
- A cheap model that needs 3 retries or manual fixes isn't cheap
- Score each engine: pass rate x cost per *successful* run
- Build a small test harness in SAS: run prompt, run generated code, compare to expected output

---

# Part 3: GitHub builds the SAS code
- Repo holds SAS programs, macros, prompts, tests
- Branch + pull request = review gate for AI-generated code
- GitHub Copilot (agent / chat) drafts code and PRs
- GitHub Actions can lint, run tests, and publish releases
- History = audit trail of what AI produced and who approved it

---

# Suggested repo layout
```
sas/            programs and macros
prompts/        versioned prompt templates
tests/          validation programs and expected output
presentation/   this deck
.github/        workflows
```

---

# Part 4: Feeding SAS Studio
Option A: raw URL
```sas
filename gh url "https://raw.githubusercontent.com/<repo>/main/sas/prog.sas";
%include gh;
```
Option B: git functions (SAS 9.4M6+ / Viya)
```sas
rc = gitfn_clone("https://github.com/<repo>.git", "/home/me/repo");
```
Option C: SAS Studio's built-in Git integration (Viya)
Code: `sas/03_github_fetch.sas`

---

# Private repos and tokens
- Use a fine-grained personal access token or deploy key, read-only
- Store in a protected file / env var, not in programs
- Pin to a tag or commit SHA in production, not `main`

---

# End-to-end workflow
1. Prompt LLM (from SAS or Copilot) to draft code
2. Commit to a branch, open a PR
3. Review + automated checks
4. Merge and tag
5. SAS Studio pulls the tag and runs it
6. Log tokens and cost per run

---

# Governance and security
- Data leaving your network: mask PII, check vendor terms
- Never commit keys; rotate if exposed
- Human review of generated code
- Keep SAS log of prompts, model, version, tokens
- Prefer enterprise endpoints with no-training guarantees

---

# Pitfalls
- Hallucinated procs/options: validate in a sandbox
- Model versions change behavior; pin versions
- Rate limits and timeouts in batch jobs
- SSL certificates / proxy settings for PROC HTTP

---

# Demo
1. Run `01_llm_call.sas` in SAS Studio
2. Run `02_cost_compare.sas` and view ranking
3. Pull `03_github_fetch.sas` from the repo

---

# Takeaways
- PROC HTTP + JSON libname is all you need
- Measure tokens, compare engines on cost per *successful* result
- GitHub gives review, history, and delivery for AI-written SAS

# Questions?
Repo: github.com/Anacreo/NoTSUG-2026-SAS-AI
