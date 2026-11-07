package pk;
  function automatic time stamp(); return $time; endfunction
endpackage
`timescale 1ns/1ps
module issue2722_package_timescale_mismatch;
  import pk::*;
  initial begin #2500; $display("pk stamp=%0d tb=%0d", stamp(), $time); end
endmodule
