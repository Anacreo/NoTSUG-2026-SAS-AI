/******************************************************************************
 Program : macros.sas
 Purpose : Shared utility macros used across the project.
 ******************************************************************************/

/* %get_env(name, default)
   Reads an OS environment variable via SYSGET and returns a default value
   when the variable is not set. Used so API keys/secrets are never
   hard-coded into the SAS programs. */
%macro get_env(name, default=);
  %local __name val;
  %let __name=%superq(name);

  %if %length(&__name.) = 0 %then %let val=;
  %else %let val = %sysfunc(sysget(&__name.));

  %if %length(&val.) = 0 %then %let val = &default.;
  &val.
%mend get_env;

/* %assert_lib_exists(libref)
   Small helper that stops program execution with a clear message if a
   required libname was not assigned (e.g. project not initialized). */
%macro assert_lib_exists(libref);
  %if %sysfunc(libref(&libref.)) ne 0 %then %do;
    %put ERROR: Library &libref. is not assigned. Run 00_setup/config.sas first.;
    %abort cancel;
  %end;
%mend assert_lib_exists;
