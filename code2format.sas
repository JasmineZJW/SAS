/* Different ways to create SAS format from a dataset, 
   simple demo, the format name will need to be updated to read from the dataset for future use. */

/* 1. Call execute */
data _null_;
    set demo end=eof;
    if _n_=1 then call execute('proc format; value visit');
    call execute(cats(AVISITN)||' = '||quote(cats(AVISIT)));
    if eof then call execute('; run;');
run;

/* 2. CNTLIN=option */
proc sql;
    create table fmt as
        select distinct 'visit' as FMTNAME
             , AVISITN as START
             , cats(AVISIT) as label
        from demo
        order by AVISITN
        ;
quit;

/* 3. Macro variable */
proc sql noprint;
    select catx(' = ', cats(AVISITN), quote(cats(AVISIT))) into :fmtlst separated by ' '
        from demo
        order by AVISITN;
quit;

proc format;
    value visit
    &fmtlst;
run;

proc format library=work cntlin=fmt;
run;

/* 4. Filename, just one of the option, not suggested to use. */
proc sql;
    create table fmt as
        select distinct AVISITN
             , quote(cats(AVISIT)) as AVISIT
        from demo
        order by AVISITN
        ;
quit;

filename code temp;
data _null_;
    file code;
    set fmt;
    if _n_=1 then put +4 'value visit';
    put +14 AVISITN ' = ' AVISIT;
run;

proc format;
    %inc code / source2;
    ;
run;