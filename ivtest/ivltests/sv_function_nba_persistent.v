// IEEE 1800-2017 13.4.4 permits a function to schedule a nonblocking
// assignment because the function itself does not suspend. The target must
// not be automatically allocated (10.4.2): this virtual-interface property
// persists even though the class method and its arguments are automatic.
typedef struct packed {
  logic [3:0] hi;
  logic [3:0] lo;
} function_nba_pair_t;

interface function_nba_if;
  function_nba_pair_t bus;
endinterface

class function_nba_cfg;
  virtual function_nba_if vif;

  function void drive(logic [3:0] hi, logic [3:0] lo);
    vif.bus.hi <= hi;
    vif.bus.lo <= lo;
  endfunction
endclass

module sv_function_nba_persistent;
  function_nba_if if0();
  function_nba_if if1();
  function_nba_cfg cfg;
  logic [3:0] module_target;
  int errors;

  function automatic logic [3:0] static_local(bit reset, bit schedule,
                                                logic [3:0] value);
    static logic [3:0] persistent;
    if (reset)
      persistent = 4'h0;
    else if (schedule)
      persistent <= value;
    static_local = persistent;
  endfunction

  function automatic void drive_module(logic [3:0] value);
    module_target <= value;
  endfunction

  initial begin
    errors = 0;
    cfg = new;
    cfg.vif = if0;
    if0.bus = 8'h00;
    if1.bus = 8'ha5;

    cfg.drive(4'h3, 4'h4);

    // Rebinding after the function returns must not redirect the scheduled
    // update, and the automatic input arguments must already be snapshots.
    cfg.vif = if1;
    if (if0.bus !== 8'h00 || if1.bus !== 8'ha5) begin
      $display("F1 active if0=%h if1=%h", if0.bus, if1.bus);
      errors++;
    end
    #0;
    if (if0.bus !== 8'h00 || if1.bus !== 8'ha5) begin
      $display("F2 inactive if0=%h if1=%h", if0.bus, if1.bus);
      errors++;
    end
    #1;
    if (if0.bus !== 8'h34 || if1.bus !== 8'ha5) begin
      $display("F3 nba if0=%h if1=%h", if0.bus, if1.bus);
      errors++;
    end

    // An explicitly static local remains a legal persistent NBA target even
    // though the surrounding function has automatic lifetime.
    void'(static_local(1, 0, '0));
    if (static_local(0, 1, 4'hd) !== 4'h0) begin
      $display("F4 static-active=%h", static_local(0, 0, '0));
      errors++;
    end
    #0;
    if (static_local(0, 0, '0) !== 4'h0) begin
      $display("F5 static-inactive=%h", static_local(0, 0, '0));
      errors++;
    end
    #1;
    if (static_local(0, 0, '0) !== 4'hd) begin
      $display("F6 static-nba=%h", static_local(0, 0, '0));
      errors++;
    end

    // The ordinary signal-NBA path has the same rule: a module variable is a
    // persistent target even when the scheduling function is automatic.
    module_target = 4'h1;
    drive_module(4'hb);
    if (module_target !== 4'h1) begin
      $display("F7 module-active=%h", module_target);
      errors++;
    end
    #0;
    if (module_target !== 4'h1) begin
      $display("F8 module-inactive=%h", module_target);
      errors++;
    end
    #1;
    if (module_target !== 4'hb) begin
      $display("F9 module-nba=%h", module_target);
      errors++;
    end

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED %0d", errors);
  end
endmodule
