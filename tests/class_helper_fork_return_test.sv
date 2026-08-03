interface class_helper_fork_return_if;
  logic clk = 1'b0;

  always #1 clk = ~clk;
endinterface

class class_helper_fork_return_cfg;
  bit in_reset;
  int mutation_count;
endclass

class class_helper_fork_return_driver;
  virtual class_helper_fork_return_if vif;
  class_helper_fork_return_cfg cfg;
  int completions;

  function new(virtual class_helper_fork_return_if vif);
    this.vif = vif;
    cfg = new;
  endfunction

  task wait_clk_or_rst();
    fork
      @(posedge vif.clk);
      wait (cfg.in_reset);
    join_any
    disable fork;
  endtask

  task channel_thread();
    repeat (40) begin
      wait_clk_or_rst();
      completions++;
    end
  endtask
endclass

module class_helper_fork_return_test;
  class_helper_fork_return_if clock_if();
  class_helper_fork_return_driver driver;

  initial begin
    driver = new(clock_if);
    fork
      driver.channel_thread();
      driver.channel_thread();
      begin
        repeat (80) begin
          #1;
          driver.cfg.mutation_count++;
        end
      end
    join

    if (driver.completions != 80) begin
      $fatal(1, "helper completed %0d calls", driver.completions);
    end

    $display("PASSED: concurrent helper forks retained class method frames");
    $finish;
  end

  initial begin
    #200;
    $fatal(1, "timeout with %0d completed helper calls", driver.completions);
  end
endmodule
