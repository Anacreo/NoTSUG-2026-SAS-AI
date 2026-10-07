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

/* %read_key_file(file, outvar)
   Reads a secret (e.g. an API key) from an external file that lives OUTSIDE
   of the repo/working copy.

   Rules:
     - Only the FIRST line of the file is used as the key.
     - Everything else is ignored.
     - Leading/trailing whitespace is trimmed.
     - Surrounding single/double quotes are stripped.

   Writes the result into the macro variable named by outvar. */
%macro read_key_file(file, outvar);
  %if %length(&outvar.) = 0 %then %return;

  %global &outvar.;
  %let &outvar.=;

  %if %length(&file.) > 0 %then %do;
    %if %sysfunc(fileexist(&file.)) %then %do;
      data _null_;
        length __line $4000;
        infile "&file." obs=1 truncover;
        input __line $char4000.;
        __line = strip(__line);

        if length(__line) >= 2 then do;
          if (substr(__line,1,1) = '"' and substr(__line,length(__line),1) = '"') or
             (substr(__line,1,1) = "'" and substr(__line,length(__line),1) = "'") then
            __line = substr(__line,2,length(__line)-2);
        end;

        call symputx("&outvar.", __line, 'G');
      run;
    %end;
  %end;
%mend read_key_file;

/* %assert_lib_exists(libref)
   Small helper that stops program execution with a clear message if a
   required libname was not assigned (e.g. project not initialized). */
%macro assert_lib_exists(libref);
  %if %sysfunc(libref(&libref.)) ne 0 %then %do;
    %put ERROR: Library &libref. is not assigned. Run 00_setup/config.sas first.;
    %abort cancel;
  %end;
%mend assert_lib_exists;
