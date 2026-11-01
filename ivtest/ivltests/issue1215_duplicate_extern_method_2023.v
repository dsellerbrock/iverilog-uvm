class C;
  extern function int f();
  extern task t();
endclass

function int C::f();
  return 1;
endfunction

function int C::f();
  return 2;
endfunction

task C::t();
endtask

task C::t();
endtask
