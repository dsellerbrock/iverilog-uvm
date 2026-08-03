interface class_method_fork_restart_if;
  logic clk = 1'b0;

  always #1 clk = ~clk;
endinterface

class class_method_fork_restart_cfg;
  bit in_reset;
endclass

class class_method_fork_restart_monitor;
  virtual class_method_fork_restart_if vif;
  class_method_fork_restart_cfg cfg;
  int restart_count;

  function new(virtual class_method_fork_restart_if vif);
    this.vif = vif;
    cfg = new;
  endfunction

  task worker();
    forever @(posedge vif.clk);
  endtask

  task process_reset();
    wait (!cfg.in_reset);
    restart_count++;
  endtask

  task run();
    forever begin
      fork
        worker();
        worker();
        worker();
        worker();
        worker();
        wait (cfg.in_reset);
      join_any
      disable fork;

      if (cfg.in_reset) process_reset();
    end
  endtask
endclass

module class_method_fork_restart_test;
  class_method_fork_restart_if clock_if();
  class_method_fork_restart_monitor monitor;

  initial begin
    monitor = new(clock_if);
    fork
      monitor.run();
    join_none

    repeat (2) begin
      repeat (3) @(posedge clock_if.clk);
      monitor.cfg.in_reset = 1'b1;
      @(posedge clock_if.clk);
      monitor.cfg.in_reset = 1'b0;
      wait (monitor.restart_count > 0);
    end

    repeat (3) @(posedge clock_if.clk);
    if (monitor.restart_count != 2) begin
      $fatal(1, "monitor restarted %0d times", monitor.restart_count);
    end

    $display("PASSED: class method retained this across repeated fork restarts");
    $finish;
  end
endmodule
