/******************************************************************************
 * Program : config.sas
 * Purpose : Central configuration for the "Ad Frequency Perception" project.
 *           Run this program FIRST in every SAS Studio session (or %include
 *           it from run_all.sas). It:
 *             1. Resolves project folders and assigns the PROJ library.
 *             2. Reads the Anthropic API key from an external key file (path
 *                supplied via autoexec.sas), falling back to an environment
 *                variable - never hard-code secrets in the code.
 *             3. Defines the list of Claude engines/models to evaluate.
 *             4. Loads shared macros and the JSON-field FCMP function.
 ******************************************************************************/

/* ---- 1. Resolve project root & folders ---------------------------------- */
/* NOTE: _SASPROGRAMFILE/SAS_EXECFILEPATH report the path of the TOP-LEVEL
   submitted program, not this %included config.sas file. That means the
   resolved path differs depending on how the project is launched:
     - Running this file directly from 00_setup/         -> .../sas/00_setup/config.sas
     - Running run_all.sas (which %includes this file)    -> .../sas/run_all.sas
   Both live either directly in "sas/" (run_all.sas) or one level below it
   (00_setup/config.sas), so we only strip the extra "00_setup" level when
   that's actually where the executing program lives. */
%let __exec_path = %sysfunc(dequote(%superq(_SASPROGRAMFILE)));
%if %length(&__exec_path.) = 0 %then %do;
  %let __exec_path = %sysfunc(dequote(%sysget(SAS_EXECFILEPATH)));
%end;

%if %length(&__exec_path.) > 0 %then %do;
  %let __exec_path = %sysfunc(tranwrd(%superq(__exec_path),%str(\),/));
%end;

%if %length(&__exec_path.) > 0 %then %do;
  %let __this_dir    = %substr(&__exec_path., 1, %eval(%length(&__exec_path.) - %length(%scan(&__exec_path., -1, /)) - 1));
  %let __last_folder = %scan(&__this_dir., -1, /);
  %if %upcase(&__last_folder.) = 00_SETUP %then %do;
    %let proj_root = %substr(&__this_dir., 1, %eval(%length(&__this_dir.) - %length(&__last_folder.) - 1));
  %end;
  %else %do;
    %let proj_root = &__this_dir.;
  %end;
%end;
%else %do;
  %let proj_root = /home/&sysuserid./NoTSUG-2026-SAS-AI/sas;
%end;

%let data_dir   = &proj_root./data;
%let output_dir = &proj_root./output;

options dlcreatedir;
libname proj "&data_dir.";

/* ---- 2. Load shared macros & helper functions --------------------------- */
%include "&proj_root./99_utils/macros.sas";
%include "&proj_root./99_utils/extract_json.sas";
options cmplib=(work.funcs);

/* ---- 3. Secrets: external key file first, then environment variable ----- */
%global anthropic_key_file;
%if not %symexist(anthropic_key_file) %then %do;
  %let anthropic_key_file =;
%end;

%read_key_file(&anthropic_key_file., anthropic_api_key_from_file);

%if %length(%superq(anthropic_api_key_from_file)) > 0 %then %do;
  %let anthropic_api_key = %superq(anthropic_api_key_from_file);
%end;
%else %do;
  %let anthropic_api_key = %get_env(ANTHROPIC_API_KEY);
%end;

%if %length(&anthropic_api_key.) = 0 %then %do;
  %put WARNING: ANTHROPIC_API_KEY could not be resolved. Point &anthropic_key_file. at a key file in autoexec.sas, or export the ANTHROPIC_API_KEY environment variable. 02_call_claude programs will fail until one is set.;
%end;

%let anthropic_api_url     = https://api.anthropic.com/v1/messages;
%let anthropic_api_version = 2023-06-01;

/* ---- 4. Claude engines to compare --------------------------------------- */
/* Selected from the models returned by /v1/models:
     Haiku 4.5  = fast/low-cost baseline
     Sonnet 5   = balanced quality/speed reference
     Opus 5.5   = highest-capability reference
*/
data proj.claude_engines;
  length engine_id $40 engine_label $60;
  input engine_id $ engine_label & $60.;
  datalines;
claude-haiku-4-5-20251001 Claude Haiku 4.5 (fast, low cost)
claude-sonnet-5           Claude Sonnet 5 (balanced)
claude-opus-5-5           Claude Opus 5.5 (highest capability)
;
run;

%put NOTE: Project root       = &proj_root.;
%put NOTE: Data directory     = &data_dir.;
%put NOTE: Output directory   = &output_dir.;
%put NOTE: Anthropic key file = &anthropic_key_file.;
%put NOTE: Claude engine set  = Haiku 4.5, Sonnet 5, Opus 5.5.;
