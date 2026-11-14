// IEEE 1800-2023 3.14 and 20.3.1: interfaces and programs carry their own
// time unit, so $time, $stime and $realtime inside their subroutines scale
// to that unit. 20.4.1: $printtimescale with no argument reports the
// design element of the current scope.
`timescale 1us/1ns
interface ifc;
  function time it(); return $time; endfunction
  function int unsigned is(); return $stime; endfunction
  function realtime ir(); return $realtime; endfunction
  task iw(); $display("interface task: $time=%0d it()=%0d", $time, it()); $printtimescale; endtask
endinterface

`timescale 10us/1ns
program prg;
  function time pt(); return $time; endfunction
  initial begin
    #0.75;                         // 7.5 us
    $display("program: $time=%0d pt()=%0d", $time, pt());
    $printtimescale;
  end
endprogram

`timescale 1us/1ns
module m;
  function time mt(); return $time; endfunction
endmodule

`timescale 1ns/1ps
module tb;
  ifc i();
  prg p();
  m u();

  initial begin
    #2500;                         // 2.5 us
    i.iw();
    $display("interface from tb: it()=%0d is()=%0d ir()=%0g", i.it(), i.is(), i.ir());
    $display("module function: mt()=%0d", u.mt());
    $display("tb: $time=%0d", $time);
    $printtimescale;
  end
endmodule
