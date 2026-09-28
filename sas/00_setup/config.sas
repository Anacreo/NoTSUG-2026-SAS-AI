/******************************************************************************
 Program : config.sas
 Purpose : Central configuration for the "Ad Frequency Perception" project.
           Run this program FIRST in every SAS Studio session (or %include
           it from run_all.sas). It:
             1. Resolves project folders and assigns the PROJ library.
             2. Reads the Anthropic API key from an environment variable
                (never hard-code secrets in the code).
             3. Defines the list of Claude engines/models to evaluate.
             4. Loads shared macros and the JSON-field FCMP function.

 Setup in SAS Studio:
   - Before running, set an environment variable (or SAS Studio "Manage
     Environment Variables") named ANTHROPIC_API_KEY with your API key.
   - Update &proj_root. below if your project folder is not auto-detected.
******************************************************************************/

/* ---- 1. Resolve project root & folders --------------------------------
   Auto-detects the "sas" project folder from the path of this file
   (.../sas/00_setup/config.sas -> .../sas). If auto-detection fails in
   your environment (e.g. running code pasted into an ad-hoc session),
   simply hard-code %let proj_root = /path/to/sas; below instead. */
%let this_file = %sysfunc(translate(%sysget(SAS_EXECFILEPATH), /, \));
%let this_dir   = %substr(&this_file., 1, %length(&this_file.) - %length(%scan(&this_file., -1, /)) - 1);
%let proj_root  = %substr(&this_dir.,  1, %length(&this_dir.)  - %length(%scan(&this_dir.,  -1, /)) - 1);

%let data_dir   = &proj_root./data;
%let output_dir = &proj_root./output;

libname proj "&data_dir.";

/* ---- 2. Load shared macros & helper functions ------------------------- */
%include "&proj_root./99_utils/macros.sas";
%include "&proj_root./99_utils/extract_json.sas";
options cmplib = (work.funcs);

/* ---- 3. Secrets: read from environment, never hard-code --------------- */
%let anthropic_api_key = %get_env(ANTHROPIC_API_KEY);
%if %length(&anthropic_api_key.) = 0 %then
  %put WARNING: ANTHROPIC_API_KEY is not set. 02_call_claude programs will fail until it is exported in your environment.;

%let anthropic_api_url     = https://api.anthropic.com/v1/messages;
%let anthropic_api_version = 2023-06-01;

/* ---- 4. Claude engines to compare -------------------------------------
   Add/remove rows to compare additional model snapshots. Keep names in
   sync with whatever models your API key has access to. */
data proj.claude_engines;
  length engine_id $ 40 engine_label $ 60;
  input engine_id $ engine_label & $60.;
  datalines;
claude-3-haiku-20240307     Claude 3 Haiku (fast, low cost)
claude-3-5-sonnet-20240620  Claude 3.5 Sonnet (balanced)
claude-3-opus-20240229      Claude 3 Opus (highest quality)
;
run;

%put NOTE: Project root   = &proj_root.;
%put NOTE: Data directory = &data_dir.;
%put NOTE: Output directory = &output_dir.;
