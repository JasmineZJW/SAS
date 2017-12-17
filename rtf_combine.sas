
/***************************************************************
*  Convert multiple rtfs into one docx and generate TOC        * 
*  Please specify the below parameters:
   path   : Path of rtf files
   tocpath: Path of toc file. TOC file should be stored in xlsx format.  
   toc    ： The file name of the TOC file, 
            no need to indicate the suffix of the file.        
   outpath: The path you want to store the combine files.
   outfile: The output file name.                          
   split  : Indicate whether to split or not. Values are indicated as Y/N.
            * Y=split the output files as Table/Figure or Listing 
            * N=combine as one big file
   keepdocx： Indicate whether to keep the combined docx file(s)  
            * Y=keep the combined docx file(s)
            * N=remove the docx file(s)                         *
* 2017-12-13： Update to read the font type from source rtf.    *
*****************************************************************/

%macro rtf_combine(path    = 
                 , tocpath = 
                 , toc     = 
                 , outpath = 
                 , outfile = 
                 , split   = 
                 , keepdocx= 
                   );

options noquotelenmax;

 /* TOC */
 /* Read the title information from TOC and assign sequence */
proc import out= toc
                datafile= "&tocpath.\&toc..xlsx"
                dbms=xlsx REPLACE;              
         getnames=no;
         datarow=2;
run;

%macro combine (TYPE=);
data toc_&TYPE.;
  set toc;
  length TFLNO SUBTFLNO $20. BOOKMARK $40. TITLE $500.;
  TFLNO=strip(E);
  SUBTFLNO=strip(A);
  CAT=substr(D,1,1);
  TITLE=catx(" ", F, G, H);
  BOOKMARK=catx("-",CAT, TFLNO, SUBTFLNO);
  %if &TYPE.=TF %then %do;
    if CAT in ("T", "F");
  %end;
  %else %if &TYPE.=L %then %do;
    if CAT in ("L");
  %end;
  keep TFLNO SUBTFLNO BOOKMARK TITLE CAT;
run;

data toc_&TYPE.;
  set toc_&TYPE.;
  SEQ=_N_;
run;

proc sort data=toc_&TYPE.; by TFLNO SUBTFLNO; run;

/* List all the rtf files in the folder
 , Put any inconsistency file names in the log
 , Read page information */
filename rtf_list pipe "dir ""&path"" /b ";

data rtf_list ;
  infile rtf_list length=reclen ;
  input FILENAME $varying3500. reclen ;
  if scan(FILENAME,2,'.') in ('doc' 'rtf');
  length TFLNO SUBTFLNO $20.;
  TFLNO = tranwrd(scan(scan(FILENAME,1,"."),1,"-"), '_','.');
  SUBTFLNO = scan(scan(scan(FILENAME,-1,'\'),1,"."),-1,"-");
  FILENAME=strip("&path")||'\'||strip(FILENAME);
run;

proc sort data=rtf_list; by TFLNO SUBTFLNO; run;

data rtf_list_&TYPE.(keep=FILENAME DTNAME TFLNO SUBTFLNO SEQ BOOKMARK TITLE CAT) 
     ;
         merge toc_&TYPE.(in=toc) rtf_list(in=rtf);
    by TFLNO SUBTFLNO; 
    length DTNAME $10. ;
    DTNAME="rtff"||strip(put(SEQ,best.));
    if toc and rtf then output rtf_list_&TYPE.;
    if toc and not rtf then do;
       n1+1;
       call symputx('check1_'||cats(n1),catx(' ',TFLNO, SUBTFLNO));
       call symputx('n1',cats(n1));
    end;
run;
 
/* Read all the rtfs into sas dataset */
%macro read_rtf (i=, in_file=, bookmark=);
    data rtff&i.;
      length FNAME&i. $80. BOOKMARK $40.;
      infile "&in_file." length=LINELEN
      FILENAME=FNAME&i. lrecl=32767 recfm=v end=eof;
      input LINEIN $varying3500. LINELEN; 
      FILENAME=FNAME&i.;
      SEQ=input(&i.,best.);
      BOOKMARK="&bookmark";
      SEQ2=_n_;
    run;
%mend;

data _null_;
    set rtf_list_&TYPE.;
    call execute('%nrstr(%read_rtf(i='||cats(SEQ)||', in_file='||cats(FILENAME)||', bookmark='||cats(BOOKMARK)||'))');
run;

/* Combine all the rtfs and update hyperlinks */
proc sql;
     select DTNAME into: DTNAME_&TYPE. separated by " " from rtf_list_&TYPE. where DTNAME ne "rtff1";
quit;

data rtf_&TYPE.;
    set rtff1(in=a) &&DTNAME_&TYPE. end=eof;
    by SEQ SEQ2;
    if a then do;
    * remove last } of first input file;
    if last.SEQ then LINEIN = substr(LINEIN, 1, length(LINEIN)-1);
    end;
    else do;
    * add page;
    if first.SEQ then LINEIN = "\sect" || LINEIN;
    end;
    if eof then do;
    * close rtf doc;
    LINEIN = trim(left(LINEIN)) || "}";
    end;
    LINEIN=tranwrd(LINEIN,"{\field{\*\fldinst { PAGE }}}", "XXX");
    LINEIN=tranwrd(LINEIN,"{\field{\*\fldinst { NUMPAGES }}}", "YYY");
    retain PCOUNT ;
    if first.SEQ then PCOUNT=0;
    if index(LINEIN, "XXX of YYY") > 0 then do;
       PCOUNT = PCOUNT + 1;
    end;
    PATTERN=prxparse('/\{.+bkmkend IDX\d+\}/');
    LINEIN=tranwrd(LINEIN,"{\*\bkmkstart IDX}", "{\*\bkmkstart "||cats(BOOKMARK)||"}");
    LINEIN=tranwrd(LINEIN,"{\*\bkmkend IDX}", "{\*\bkmkend "||cats(BOOKMARK)||"}");
    if index(LINEIN, '\*\bkmkstart IDX') then do;
      call prxsubstr(PATTERN, LINEIN, START, LENGTH);
      LINEIN=cats(substr(LINEIN, 1, START-1),substr(LINEIN, LENGTH+START));
    end;
    drop START LENGTH;
run;

/* To read the front from the source rtf */
proc sql;
  select substr(LINEIN,1,index(LINEIN,";")-1) 
         into: line_1 from rtff1 where index(LINEIN, "{\f1\f");
  select substr(LINEIN,1,index(LINEIN,";")-1) 
         into: line_2 from rtff1 where index(LINEIN, "{\f2\f");
quit;

proc datasets lib=work;
   delete &&DTNAME_&TYPE.;
quit;

proc sql;
    create table rtf_&TYPE._ as
        select SEQ, count(*) as TOTPAGEN from
        rtf_&TYPE.
        where index(LINEIN,"XXX of YYY")
        group by SEQ
        ;
quit;

data rtf_final_&TYPE.;
    if 0 then set rtf_&TYPE._;
    set rtf_&TYPE.;
    by SEQ;
    if _n_=1 then do;
      declare hash totp (dataset: cats('rtf_',"&type.",'_'));
      totp.definekey ('SEQ');
      totp.definedata ('TOTPAGEN');
      totp.definedone ();
    end;
    if totp.find () ge 0;
    retain FIRSTP;
    LAGTOT=lag(TOTPAGEN);
    if SEQ=1 then FIRSTP=1;
    if first.SEQ and SEQ ne 1 then FIRSTP=LAGTOT+FIRSTP;
    ORDER=2;
    drop LAGTOT;
run;

proc datasets lib=work;
   delete rtff_&TYPE. ;
quit;

data tocpg;
    if 0 then set rtf_final_&TYPE.;
    set toc_&TYPE.;
    if _n_=1 then do;
      declare hash firstpage (dataset: cats('rtf_final_',"&TYPE."));
      firstpage.definekey ('SEQ');
      firstpage.definedata ('FIRSTP');
      firstpage.definedone ();
    end;
    if firstpage.find () eq 0;
    length FIRSTPC $5.;
    FIRSTPC=strip(put(FIRSTP, best.));
    keep SEQ TFLNO SUBTFLNO TITLE FIRSTPC BOOKMARK;
run;

proc sort data=tocpg; by SEQ; run;

data toc_start;
    length LINEIN $3500.;
    ORDER=0;
    SEQ=0;
    /* Setup the rtf structure for TOC page */
    LINEIN = "{\rtf1\ansi\ansicpg932\uc1\deff0\deflang1041\deflangfe1041"; output;
    LINEIN = "{\fonttbl"; output;
    LINEIN = strip("&line_1.")||" ;}"; output;
    LINEIN = strip("&line_2.")||" ;}"; output;
    LINEIN = "}{\stylesheet{\widctlpar\adjustright\fs20\cgrid\snext0 Normal;}{\*\cs10\additive Default Paragraph Font;}"; output;
    LINEIN = "}"; output;
    LINEIN = "\pard\sa400\f0\fs50\b\qc Table of Contents\par"; output;
    LINEIN = "\widowctrl\ftnbj\aenddoc\formshade\viewkind1\viewscale100\pgbrdrhead\pgbrdrfoot\fet0\paperw16837\paperh11905\margl1440\margr1440\margt1701\margb1440"; output;
    keep LINEIN ORDER SEQ;
run;

%macro toc (bookmark=, tflno=, title=, nspace=, firstp=);
    LINEIN = '\pard\sa200\li2000\f0\fs20\b0\ql{\field{\*\fldinst HYPERLINK  \\l "'||strip(&bookmark.)||'"}'; output;
    LINEIN = '{\fldrslt \li18000\fi200 '||strip(&tflno.)||' \tx2000\tab '||strip(&title.)||' \ptabldot\pindtabqr '||strip(&firstp.)||'}}'; output;
    LINEIN = '\ri2000\par';output;
%mend;

data toc_content;
    set tocpg;
    length LINEIN $3500.;
    ORDER=1;
    SEQ=0;
    %toc(bookmark=%nrbquote(BOOKMARK), tflno=%nrbquote(TFLNO), title=%nrbquote(TITLE), nspace=NUM, firstp=FIRSTPC);
    keep LINEIN ORDER SEQ;
run;

data _null_;
 set toc_start toc_content(in=a) rtf_final_&TYPE.(in=b) end=eof;
 by ORDER SEQ;
 file "&outpath.\&outfile._&TYPE..rtf" lrecl = 2000;
    * add page;
 if b and first.ORDER then LINEIN = "\sect" || LINEIN;

 if eof then do;
    * close rtf doc;
    LINEIN = trim(left(LINEIN)) || "}";
    end;
if index(LINEIN, "XXX of YYY") then do;
  MOFN = compress(put(PCOUNT,8.)) || " of " || compress(put(TOTPAGEN,8.));
  LINEIN = tranwrd(LINEIN, "XXX of YYY", MOFN);
 end; 
 LINELEN =length(LINEIN);
put LINEIN $varying3500. LINELEN;
run;


%let rtf=%unquote(%str("&outpath.\&outfile._&TYPE..rtf"));
%let docx=%unquote(%str("&outpath.\&outfile._&TYPE..docx"));
%let vbscript=%unquote(%str("&outpath.\&outfile..vbs"));

/* Convert the rtf file into docx file, then remove the rtf file */
filename vbscript ""&vbscript"";
data _null_;
  file vbscript;
  put
      "Const RTF_DOCX = 16"
    / "Const RTF_IN="&rtf""
    / "Const DOCX_OUT="&docx""
    / "Set objWord = CreateObject(""Word.Application"")"
    / "Wscript.Sleep 500"
    / "objWord.Visible = False"
    / "Set objDocument = objWord.Documents.Open(RTF_IN,,False)"
    / "Wscript.Sleep 300"
    / "objDocument.SaveAs DOCX_OUT, RTF_DOCX"
    / "objDocument.Close False"
    / "objWord.Quit"
    ;
run;
filename vbscript;

data _null_;
  /* execute vbs */
  call system(""&vbscript"");
  /* clean up: delete rtf */
  call system("del /q  "&rtf"");
 run;

/* Convert the docx file into pdf file */
%let pdf=&outpath.\&outfile._&TYPE..pdf;
%let docx=&outpath.\&outfile._&TYPE..docx;

filename vbscript ""&vbscript"";
data _null_;
  file vbscript;
  length vbscmd $200.;
  put 'Dim objWord';
  put 'Dim objWordDoc';
  put 'Set objWord = CreateObject("Word.Application")';
  put 'Wscript.Sleep 500';
  put 'objWord.Visible = False';
  vbscmd='Set objWordDoc = objWord.Documents.Open("'|| "&docx" ||'")';
  put vbscmd;
  put 'Wscript.Sleep 300';
  vbscmd='objWordDoc.ExportAsFixedFormat "'||"&pdf"||'", 17, False,1,0,1,1,0,False,True,2,False,True,False';
  put vbscmd;
  put 'objWordDoc.Close False';
  put 'objWord.Quit';
run;

filename vbscript;

data _null_;
  /* execute vbs */
  call system(""&vbscript"");
  /* clean up: delete  vbs */
  call system("del /q "&vbscript"");
  /* clean up: delete  docx */
  %if &keepdocx.=N %then %do;
     call system("del /q &docx");
  %end;
run;

/* Put the issue in the log */
%if %symexist(n1) %then %do;
    %put ============================================================;
    %put  ;
    %if %symexist(n1) %then %do;
        %do i = 1 %to &n1;
            %if &i=1 %then %put TFL exists in toc but not in rtf path:;
            %put %str(        ) &&check1_&i;
        %end;
    %end;
    %put  ;
    %put ============================================================;

%end;

%mend combine;

%if &split.=N %then %do;
  %combine(TYPE=ALL);
%end;

%if &split.=Y %then %do;
  %combine(TYPE=TF);
  %combine(TYPE=L);
%end;

%mend rtf_combine;

