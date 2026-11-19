`timescale 1ns/1ns

module top;
  logic gate, pulse = 0, startup_signal;
  int steps = 0, dynamic_hits = 0, event_hits = 0;
  int true_hits = 0, initialized_value = 0, dead_hits = 0, startup_hits = 0;

  task single_wait;
    wait (1) true_hits = true_hits + 1;
  endtask

  task worker;
    steps = 1;
    wait (gate) begin
      wait (1) dynamic_hits = dynamic_hits + 1;
    end
    @(posedge pulse) event_hits = event_hits + 1;
    steps = 2;
  endtask

  task automatic with_initializer;
    int seed = 9;
    wait (1) begin : payload
      int value = seed + 1;
      initialized_value = value;
    end
  endtask

  task null_body;
    wait (1);
  endtask

  task empty_block;
    wait (1) begin end
  endtask

  task suspended;
    wait (0) begin : dead
      @(posedge pulse) dead_hits = dead_hits + 1;
      wait (1) dead_hits = dead_hits + 1;
    end
  endtask

  // The inner @ must still arm before time-zero Active work.
  always wait (1) begin
    @(startup_signal) startup_hits = startup_hits + 1;
  end

  initial begin
    startup_signal = 0;
    $probe_wait_stmt;
    #1;
    single_wait;
    with_initializer;
    null_body;
    empty_block;
    fork
      worker;
      suspended;
    join_none
    #1;
    if (steps != 1 || dynamic_hits != 0 || gate !== 1'bx)
      $fatal(1, "wait did not suspend on X");
    gate = 0;
    #2;
    if (steps != 1 || dynamic_hits != 0)
      $fatal(1, "wait did not remain suspended on 0");
    gate = 1;
    #1;
    if (steps != 1 || dynamic_hits != 1 || event_hits != 0)
      $fatal(1, "wait did not release at time 4 or @ did not suspend");
    pulse = 1;
    #1;
    if (steps != 2 || dynamic_hits != 1 || event_hits != 1 ||
        dead_hits != 0 || true_hits != 1 || initialized_value != 10 ||
        startup_hits != 1)
      $fatal(1, "unexpected executions after the event");
    $check_wait_stmt;
    $finish(0);
  end
endmodule
