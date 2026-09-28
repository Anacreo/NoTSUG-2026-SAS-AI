/****************************************************************************
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
   - If automatic path detection fails, set &proj_root manually below.
 ****************************************************************************/

/* ---- 1. Resolve project root & folders ----------------------------------
   Studio-safe resolution order:
   1) _SASPROGRAMFILE (SAS Studio/EG)
   2) SAS_EXECFILEPATH (some environments)
   3) Manual fallback path (edit as needed)
*/
%let __exec_path = %sysfunc(dequote(%superq(_SASPROGRAMFILE)));
%if %length(&__exec_path.) = 0 %then %let __exec_path = %sysfunc(dequote(%sysget(SAS_EXECFILEPATH)));

/* Normalize slashes */
%if %length(&__exec_path.) > 0 %then %let __exec_path = %sysfunc(translate(&__exec_path.,/,\));

/* Derive .../sas from .../sas/00_setup/config.sas when path is available */
%if %length(&__exec_path.) > 0 %then %do;
  %let __this_dir  = %substr(&__exec_path., 1, %eval(%length(&__exec_path.) - %length(%scan(&__exec_path., -1, /)) - 1));
  %let proj_root   = %substr(&__this_dir.,  1, %eval(%length(&__this_dir.)  - %length(%scan(&__this_dir.,  -1, /)) - 1));
%end;
%else %do;
  /* Manual fallback: update this path for your SAS Studio home location */
  %let proj_root = /home/&sysuserid./NoTSUG-2026-SAS-AI/sas;
%end;

%let data_dir   = &proj_root./data;
%let output_dir = &proj_root./output;

/* Ensure key directories exist before LIBNAME assignment */
options dlcreatedir;
libname proj "&data_dir.";

/* ---- 2. Load shared macros & helper functions --------------------------- */
%include "&proj_root./99_utils/macros.sas";
%include "&proj_root./99_utils/extract_json.sas";
options cmplib=(work.funcs);

/* ---- 3. Secrets: read from environment, never hard-code ----------------- */
%let anthropic_api_key = %get_env(ANTHROPIC_API_KEY);
%if %length(&anthropic_api_key.) = 0 %then
  %put WARNING: ANTHROPIC_API_KEY is not set. 02_call_claude programs will fail until it is exported in your environment.;

%let anthropic_api_url     = https://api.anthropic.com/v1/messages;
%let anthropic_api_version = 2023-06-01;

/* ---- 4. Claude engines to compare ---------------------------------------
   Add/remove rows to compare additional model snapshots. Keep names in
   sync with whatever models your API key has access to. */
data proj.claude_engines;
  length engine_id $40 engine_label $60;
  input engine_id $ engine_label & $60.;
  datalines;
claude-3-haiku-20240307     Claude 3 Haiku (fast, low cost)
claude-3-5-sonnet-20240620  Claude 3.5 Sonnet (balanced)
claude-3-opus-20240229      Claude 3 Opus (highest quality)
;
run;

%put NOTE: Project root     = &proj_root.;
%put NOTE: Data directory   = &data_dir.;
%put NOTE: Output directory = &output_dir.;
