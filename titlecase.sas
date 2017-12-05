/************************************************************************************************
 *  A macro to check title case when adding variables/values into SDTM/ADaM datasets            *
 *  Parameters:                                                                                 *
 *              indt_  : specify the input dataset which includes labels to be checked.         *
 *              invar_ : specify the variable name that store the label.                        *
 *              outdt_ : specify the name of output dataset.                                    *
 *              excl   : specify the articles, prepositions, 
                         and conjunctions that need to exclude from title case.                 *
 ************************************************************************************************/


%macro titlecase(indt_=
               , invar_=
               , outdt_=
               , excl=);
  data &outdt_.;
      set &indt_.;
      length LABEL $40.;
      LABEL = &invar_.;
      /* Upcase the first character of each word */
      START = 1;
      STOP  =length(LABEL);
      REUC  = prxparse("/\b\w/");
      call prxnext (REUC, START, STOP, LABEL, POS, LENGTH);
      do while (POS > 0);
          call prxnext (REUC, START, STOP, LABEL, POS, LENGTH);
          LABEL = substr(LABEL, 1, START-2)||upcase(substr(LABEL, START-1, 1))||substr(LABEL, START);
      end; 
      /* exclude the pre-defined values (prepositions, etc.) */  
      %let i=1;
      %let val=%scan(&excl.,&i.,"|");
      %do %while(%str(&val.) ne );
          LABEL=cat(substr(LABEL,1,1),prxchange("s/\b&val.\b/&val./i", -1, substr(LABEL,2)));
          %let i=%eval(&i+1);
          %let val=%scan(&excl.,&i.,"|");
      %end;
      if &invar_. ne LABEL then output;
  run;
%mend;
