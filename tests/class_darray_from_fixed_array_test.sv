// IEEE 1800-2017 7.6: assignment from a compatible fixed-size unpacked
// array to a dynamic array resizes the destination and copies every value.
package class_darray_from_fixed_array_pkg;
  parameter string ALERT_NAMES[2] = {"recoverable", "fatal"};
endpackage

class class_darray_from_fixed_array_cfg;
  string names[] = {};

  function void initialize();
    names = class_darray_from_fixed_array_pkg::ALERT_NAMES;
  endfunction
endclass

module class_darray_from_fixed_array_test;
  initial begin
    class_darray_from_fixed_array_cfg cfg;
    string standalone[];
    cfg = new;
    cfg.initialize();
    standalone = class_darray_from_fixed_array_pkg::ALERT_NAMES;
    if (cfg.names.size() == 2 &&
        cfg.names[0] == "recoverable" && cfg.names[1] == "fatal" &&
        "recoverable" inside {cfg.names} &&
        !("missing" inside {cfg.names}) &&
        standalone.size() == 2 &&
        "fatal" inside {standalone} &&
        !("missing" inside {standalone}))
      $display("PASS class_darray_from_fixed_array_test");
    else
      $display("FAIL class_darray_from_fixed_array_test size=%0d names=%p",
               cfg.names.size(), cfg.names);
    $finish;
  end
endmodule
