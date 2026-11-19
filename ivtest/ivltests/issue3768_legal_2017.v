int shared = 90;
int payload = 99;

package provider;
  localparam int from_import = 11;
  typedef struct packed {int value;} record_t;
  record_t payload = {32'd17};
endpackage

import provider::from_import;

package clean;
  import provider::payload;
  int shared = 23;

  function automatic int combined();
    int shared = 5;
    return shared + clean::shared + from_import
         + payload.value + provider::payload.value;
  endfunction
endpackage

module test;
  initial begin
    if (shared !== 90 || $unit::shared !== 90 || clean::combined() !== 73)
      $fatal(1, "Incorrect local shadowing or imported binding");
    $display("PASSED");
  end
endmodule
