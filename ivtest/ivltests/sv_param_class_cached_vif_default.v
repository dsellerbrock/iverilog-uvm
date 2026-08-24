// A repeated lookup of the same parameterized-class specialization must not
// elaborate its method bodies before concrete interface instances exist.
// IEEE 1800-2023 25.9 permits class properties to hold virtual interfaces,
// and 13.5.3 evaluates an omitted default argument in the subroutine's
// declaration scope each time the call is made.

interface cached_vif_default_if;
  localparam int LOCAL_STEP = 3;
  int seed;
  int last = -1;
  int calls = 0;
  int last_drive = -1;
  int drive_calls = 0;

  task automatic poke(int value = seed + LOCAL_STEP);
    last = value;
    calls += 1;
  endtask

  task automatic drive(int value);
    last_drive = value;
    drive_calls += 1;
  endtask
endinterface

package cached_vif_default_pkg;
  class cfg_base;
    virtual cached_vif_default_if scalar;
    virtual cached_vif_default_if by_name[string];
  endclass

  class cfg_concrete extends cfg_base;
  endclass

  class runner_base #(type CFG = cfg_base);
    CFG cfg;

    task run(string key);
      cfg.scalar.poke();
      cfg.by_name[key].poke();
      cfg.scalar.drive(101);
      cfg.by_name[key].drive(202);
    endtask
  endclass

  // The second declaration is a semantic specialization-cache hit for the
  // same runner_base#(cfg_concrete). Both derived types must share a fully
  // formed specialization without forcing its body to elaborate early.
  class first_runner extends runner_base #(cfg_concrete);
  endclass

  class second_runner extends runner_base #(cfg_concrete);
  endclass
endpackage

module sv_param_class_cached_vif_default;
  import cached_vif_default_pkg::*;

  cached_vif_default_if if0();
  cached_vif_default_if if1();
  cached_vif_default_if if2();
  cached_vif_default_if if3();

  first_runner first;
  second_runner second;
  cfg_concrete first_cfg;
  cfg_concrete second_cfg;

  initial begin
    first = new;
    second = new;
    first_cfg = new;
    second_cfg = new;
    first.cfg = first_cfg;
    second.cfg = second_cfg;

    if0.seed = 10;
    if1.seed = 20;
    if2.seed = 30;
    if3.seed = 40;

    first_cfg.scalar = if0;
    first_cfg.by_name["named"] = if1;
    second_cfg.scalar = if2;
    second_cfg.by_name["named"] = if3;

    first.run("named");
    second.run("named");

    // Rebind both receiver forms and reuse the same call sites. Dispatch and
    // declaration-scoped defaults must follow the newly selected instances.
    first_cfg.scalar = if3;
    first_cfg.by_name["named"] = if0;
    first.run("named");

    if (if0.last != 13 || if0.calls != 2
        || if0.last_drive != 202 || if0.drive_calls != 2
        || if1.last != 23 || if1.calls != 1
        || if1.last_drive != 202 || if1.drive_calls != 1
        || if2.last != 33 || if2.calls != 1
        || if2.last_drive != 101 || if2.drive_calls != 1
        || if3.last != 43 || if3.calls != 2
        || if3.last_drive != 101 || if3.drive_calls != 2) begin
      $display("FAILED if0=%0d/%0d/%0d/%0d if1=%0d/%0d/%0d/%0d",
               if0.last, if0.calls, if0.last_drive, if0.drive_calls,
               if1.last, if1.calls, if1.last_drive, if1.drive_calls);
      $display("FAILED if2=%0d/%0d/%0d/%0d if3=%0d/%0d/%0d/%0d",
               if2.last, if2.calls, if2.last_drive, if2.drive_calls,
               if3.last, if3.calls, if3.last_drive, if3.drive_calls);
    end else begin
      $display("PASSED");
    end
    $finish(0);
  end
endmodule
