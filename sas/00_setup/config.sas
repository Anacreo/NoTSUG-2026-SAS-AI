/******************************************************************************
 Program : config.sas
 Purpose : Central configuration for the "Ad Frequency Perception" project.
           Run this program FIRST in every SAS Studio session (or %include
           it from run_all.sas). It:
             1. Resolves project folders and assigns the PROJ library.
             2. Reads the Anthropic API key from an external key file (path
                supplied via autoexec.sas), falling back to an environment
                variable - never hard-code secrets in the code.
             3. Defines the list of Claude engines/models to evaluate.
             4. Loads shared macros and the JSON-field FCMP function.

 Setup in SAS Studio (one-time, per environment):
   - Store your Anthropic API key in a file OUTSIDE of this repo, e.g.
       /home/<you>/SSHKeys/Anthropic.key
     Only the FIRST line of that file is read as the key; anything else
     in the file is ignored, so you're free to leave notes below it.
   - In SAS Studio, open "Autoexec File" (gear/File menu -> Edit Autoexec
     File) and add a line pointing at your key file, e.g.:
       %global anthropic_key_file;
       %let anthropic_key_file = /home/<you>/SSHKeys/Anthropic.key;
     This keeps the secret path out of the repo entirely - config.sas just
     reads whatever &anthropic_key_file. resolves to at run time.
   - If autoexec.sas doesn't define anthropic_key_file (or the file can't
     be read), config.sas falls back to the ANTHROPIC_API_KEY environment
     variable (SAS Studio "Manage Environment Variables").
   - If automatic project-path detection fails, set &proj_root manually
     below.
 ****************************************************************************/

/* ---- 1. Resolve project root & folders ----------------------------------
   Studio-safe resolution order:
   1) _SASPROGRAMFILE (SAS Studio/EG)
   2) SAS_EXECFILEPATH (some environments)
   3) Manual fallback path (edit as needed)
*/
%let __exec_path = %sysfunc(dequote(%superq(_SASPROGRAMFILE)));
%if %length(&__exec_path.) = 0 %then %do;
  %let __exec_path = %sysfunc(dequote(%sysget(SAS_EXECFILEPATH)));
%end;

/* Normalize slashes: convert backslash -> slash safely */
%if %length(&__exec_path.) > 0 %then %do;
  %let __exec_path = %sysfunc(tranwrd(%superq(__exec_path),%str(\),/));
%end;

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

/* ---- 3. Secrets: external key file first, then environment variable -----
   &anthropic_key_file. is expected to be defined in your SAS Studio
   autoexec.sas (see header comment above) and point at a file that lives
   outside of this repo. Only the first line of that file is read. */
%global anthropic_key_file;
%if not %symexist(anthropic_key_file) %then %do;
  %let anthropic_key_file =;
%end;

%let anthropic_api_key = %read_key_file(&anthropic_key_file., default=%get_env(ANTHROPIC_API_KEY));

%if %length(&anthropic_api_key.) = 0 %then %do;
  %put WARNING: ANTHROPIC_API_KEY could not be resolved. Point &anthropic_key_file. at a key file in autoexec.sas, or export the ANTHROPIC_API_KEY environment variable. 02_call_claude programs will fail until then.;
%end;

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
%put NOTE: Anthropic key file = &anthropic_key_file.;
