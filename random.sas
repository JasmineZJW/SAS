/* Different ways to generate the integer random numbers */

/* Define user-specific function to obtain the random numbers */
proc fcmp outlib=work.myfunc.sample;
    function RandBetween(min, max);
    return (min + floor((1 + max - min) * rand("uniform")));
    endsub;
run;

options cmplib=work.myfunc;

data RandInt;
   do i = 1 to 100;
      x2 = RandBetween(1, 100);
      output;
   end;
run;

/* Define a SAS macro */
%macro RandBetween(min, max);
   (&min + floor((1+&max-&min)*rand("uniform")))
%mend;

data RandInt;
   do i = 1 to 100;
       x = %RandBetween(1, 10);
       output;
   end;
run;

/* A SAS/IML function for random integers */
proc iml;
/* Generate n random integers drawn uniformly at random from 
   integers in [min, max] where min and max are integers. */
    start RandBetween(n, min, max);
       u = j(n, 1);
       call randgen(u, "Uniform", min, max+1);
       return( floor(u) );
    finish;
 
/* Test the function. Generate 10 values and tabulate the result. */
    call randseed(1234);
    x = RandBetween(10, 1, 100);
    call tabulate(val, freq, x);
print freq[c=(char(val))];

/* New built-in support for random integers, requires SAS 9.4M4 or later */
data RandInt;
do i = 1 to 100;
   x = rand("Integer", 1, 10); 
   output;
end;
run;