%macro splitaddvar_JP(in_data=, in_var=, out_data=, out_pre=);

%let ZERODATA = ;
proc sql noprint;
select memname into :ZERODATA SEPARATED by '","'
from sashelp.vtable where libname = "WORK" and memname = %upcase("&in_data.") and nobs = 0;
quit;

%if &ZERODATA. eq %then %do;
/* Rename the variable name to avoid multiple lengths */
  data &in_data.;
      set &in_data.;
      length _&in_var._ $10000;
      _&in_var._ = &in_var.;
      drop &in_var.;
  run;

  /* Count the maximum variables required */
  proc sql;
    select cats(ceil(max(length(_&in_var._))/200)+1) into :dim from &in_data.;
  quit;

  %let dim_ = %eval(&dim.-1);

  /* To cut the variables based on the number of the double byte characters and single byte characters */
  data &out_data.;
     set &in_data.;
     array _x $200 &out_pre. &out_pre.1-&out_pre.&dim_.;
     array _xleft LEFT LEFT1-LEFT&dim_.;
     array _xnum NUM NUM1-NUM&dim_.;
    do i=1 to 8 while (not missing(_&in_var._));
      _x(i) = substr(_&in_var._,1,200);
      TEST=substr(_&in_var._,1,200);
      CNUM=compress(TEST,,'kw');
      _xnum(i) = lengthn(compress(tranwrd(_x(i), '', '*'),,'kw'));
      _xleft(i) = mod((200-_xnum(i)),3);
      _x(i) = substr(_x(i),1,200-_xleft(i));
      _&in_var._ = substr(_&in_var._,(length(_x(i))+1));
    end;
  run;

data &out_data.;
   set &out_data.;
run;
%end;
%mend splitaddvar_JP;