// Method calls through a virtual interface to a statically named nested
// interface instance (IEEE 1800-2017 25.10). The outer virtual-interface
// handle must select the correct outer instance at run time, and named/default
// arguments on the nested method must retain normal function-call semantics.

interface nested_control_if;
  int period = 0;
  bit drive_clk = 0;
  bit drive_rst_n = 0;

  function automatic void set_active(bit drive_clk_val = 1'b1,
                                     bit drive_rst_n_val = 1'b1);
    drive_clk = drive_clk_val;
    drive_rst_n = drive_rst_n_val;
  endfunction

  function automatic void set_period(int value);
    period = value;
  endfunction
endinterface

interface outer_control_if;
  nested_control_if nested();
endinterface

class nested_vif_config;
  virtual outer_control_if vif;
endclass

class nested_vif_controller;
  function void start(nested_vif_config local_cfg, int period);
    local_cfg.vif.nested.set_active(.drive_rst_n_val(1'b0));
    local_cfg.vif.nested.set_period(period);
  endfunction
endclass

module sv_vif_nested_interface_method;
  outer_control_if outer0();
  outer_control_if outer1();
  int errors = 0;

  initial begin
    nested_vif_controller controller;
    nested_vif_config cfg;
    controller = new;
    cfg = new;

    cfg.vif = outer1;
    controller.start(cfg, 11);
    if (outer1.nested.period !== 11 || outer1.nested.drive_clk !== 1'b1
        || outer1.nested.drive_rst_n !== 1'b0) begin
      $display("FAIL outer1 period=%0d drive_clk=%b drive_rst_n=%b",
               outer1.nested.period, outer1.nested.drive_clk,
               outer1.nested.drive_rst_n);
      errors++;
    end
    if (outer0.nested.period !== 0 || outer0.nested.drive_clk !== 1'b0) begin
      $display("FAIL call through outer1 changed outer0");
      errors++;
    end

    cfg.vif = outer0;
    controller.start(cfg, 23);
    if (outer0.nested.period !== 23 || outer0.nested.drive_clk !== 1'b1
        || outer0.nested.drive_rst_n !== 1'b0) begin
      $display("FAIL outer0 period=%0d drive_clk=%b drive_rst_n=%b",
               outer0.nested.period, outer0.nested.drive_clk,
               outer0.nested.drive_rst_n);
      errors++;
    end
    if (outer1.nested.period !== 11) begin
      $display("FAIL call through outer0 changed outer1");
      errors++;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end
endmodule
