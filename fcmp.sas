proc fcmp outlib=work.myfunc.sample;
    function RandBetween(min, max);
    return (min + floor((1 + max - min) * rand("uniform")));
    endsub;
run;

options cmplib=work.myfunc;

data RandInt;
   do i = 1 to 100;
      x2 = RandBetween(101, 110);
      output;
   end;
run;