// A named argument on a virtual-interface task call keeps its formal
// position, omitted formals use their declared defaults, and assignment
// conversion sizes each actual to its formal (IEEE 1800-2017 13.5, 25.10).

package vif_named_default_pkg;
  typedef enum logic [1:0] {
    Async = 2'd1,
    Sync  = 2'd2
  } scheme_t;
endpackage

interface vif_named_default_if;
  import vif_named_default_pkg::*;

  int seen_width;
  int seen_delay;
  scheme_t seen_scheme = Async;

  task automatic apply_reset(int width = 55,
                             int delay_clks = 9,
                             scheme_t scheme = Async);
    seen_width = width;
    seen_delay = delay_clks;
    seen_scheme = scheme;
  endtask
endinterface

class vif_named_default_driver;
  virtual vif_named_default_if vif;

  task run;
    // The 2-bit enum is formal 3, not a positional value for 32-bit formal 1.
    vif.apply_reset(.scheme(vif_named_default_pkg::Sync));
  endtask
endclass

module sv_vif_named_default_args;
  import vif_named_default_pkg::*;

  vif_named_default_if if0();
  vif_named_default_if if1();
  vif_named_default_driver driver;
  int errors;

  initial begin
    driver = new;
    driver.vif = if1;
    driver.run();

    if (if1.seen_width !== 55 || if1.seen_delay !== 9
        || if1.seen_scheme !== Sync) begin
      $display("FAIL selected width=%0d delay=%0d scheme=%0d",
               if1.seen_width, if1.seen_delay, if1.seen_scheme);
      errors++;
    end
    if (if0.seen_width !== 0 || if0.seen_delay !== 0
        || if0.seen_scheme !== Async) begin
      $display("FAIL unselected instance changed");
      errors++;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
