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

/* All conditional macro logic is inside a macro because SAS does not support
   %IF/%ELSE/%DO/%END statements in open code. */
%macro initialize_config;

  /* ---- 1. Resolve project root & folders ------------------------------- */
  /* When run_all.sas includes this file, __run_dir was derived from the
     submitted run_all.sas path and already identifies the sas/ directory.
     When config.sas is run directly, derive the sas/ directory from the
     submitted program path by removing the 00_setup/config.sas suffix. */
  %if %length(%superq(__run_dir)) > 0 %then %do;
    %let proj_root = %superq(__run_dir);
  %end;
  %else %do;
    %let __exec_path = %sysfunc(dequote(%superq(_SASPROGRAMFILE)));
    %if %length(%superq(__exec_path)) = 0 %then %do;
      %let __exec_path = %sysfunc(dequote(%sysget(SAS_EXECFILEPATH)));
    %end;

    %let __exec_path = %sysfunc(tranwrd(%superq(__exec_path),%str(\),/));
    %let proj_root = %sysfunc(
      prxchange(s#/00_setup/config\.sas$##i,1,%superq(__exec_path))
    );

    %if %length(%superq(proj_root)) = 0 %then %do;
      %let proj_root = /home/&sysuserid./NoTSUG-2026-SAS-AI/sas;
    %end;
  %end;

  %let data_dir   = &proj_root./data;
  %let output_dir = &proj_root./output;

  options dlcreatedir;
  libname proj "&data_dir.";

  /* ---- 2. Load shared macros & helper functions ----------------------- */
  %include "&proj_root./99_utils/macros.sas";
  %include "&proj_root./99_utils/extract_json.sas";
  options cmplib=(work.funcs);

  /* ---- 3. Secrets: external key file first, then environment variable - */
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

  %if %length(%superq(anthropic_api_key)) = 0 %then %do;
    %put WARNING: ANTHROPIC_API_KEY could not be resolved. Point &anthropic_key_file. at a key file in autoexec.sas, or export the ANTHROPIC_API_KEY environment variable. 02_call_claude programs will fail until one is set.;
  %end;

  %let anthropic_api_url     = https://api.anthropic.com/v1/messages;
  %let anthropic_api_version = 2023-06-01;

  /* ---- 4. Claude engines to compare ----------------------------------- */
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

%mend initialize_config;

%initialize_config;
