// IEEE 1800-2017/2023 16.5.1 and 16.9.3.
module issue709_sampled;
  logic [7:0] value = 8'h12;
  logic unwritten;
  logic signed [79:0] wide = -80'sd4;
  logic [3:0] words [2:3];
  int index = 1;
  real amount = 1.25;
  bit clk = 0;
  wire [64:0] driven = 65'd1;

  wire resolved_net;
  assign (strong1, strong0) resolved_net = value[1];
  assign (weak1, weak0) resolved_net = 1'b0;

`ifdef ISSUE709_BAD_SKEW
  clocking cb @(posedge clk);
    input #2 value;
  endclocking
  initial $display("%h", $sampled(cb.value));
`else
  typedef enum bit [3:0] { FIRST = 3, SECOND = 6 } state_t;
  state_t state = FIRST, sampled_state;
  event mark;
  bit action_checked = 0;
  issue709_sampled_bus bus();
  issue709_sampled_sink sink(bus);

  clocking cb @(posedge clk);
    input #1step value;
  endclocking

  function automatic logic [7:0] plus_live(input logic [7:0] arg);
    return arg + value;
  endfunction

  task automatic check_index(input int automatic_index);
    automatic_index = 4;
    if ($sampled(value[automatic_index]) !== 1'b1)
      $fatal(1, "automatic select index did not use its current value");
  endtask

  always @(cb)
    if ($sampled(cb.value) !== 8'h34)
      $fatal(1, "clocking input did not use the block's #1step sample");

  assert property (@(posedge clk) 1'b0)
  else begin
    if ($sampled(value) !== 8'h34 || value !== 8'h56)
      $fatal(1, "assertion action read the wrong slot value");
    action_checked = 1;
  end

  initial begin
    unwritten = 1;
    amount = 3.75;
    if ($sampled(value) !== 8'h12 || $sampled(unwritten) !== 1'bx ||
        $sampled(amount) != 1.25 || $sampled(driven) !== {65{1'bx}})
      $fatal(1, "incorrect time-zero sampled defaults");
    words[2] = 4'h3;

    #1;
    if ($sampled(value) !== 8'h12 || $sampled(driven) !== 65'd1)
      $fatal(1, "incorrect sample before the slot's first write");
    value = 8'h34;
    wide = 80'sh100;
    state = SECOND;
    sampled_state = $sampled(state);
    if (sampled_state !== FIRST)
      $fatal(1, "sampled enum lost its type or value");
    index = 0;
    amount = 6.5;
    force resolved_net = 1'b0;
    force words[2] = 4'h0;
    force amount = 9.25;
    if ($sampled(value) !== 8'h12 || $sampled(value[index]) !== 1'b1 ||
        $sampled(words[index+1]) !== 4'h3 ||
        $sampled(wide + 80'sd1) !== -80'sd3 || $sampled(wide) >= 0 ||
        $bits($sampled(wide)) != 80 || $sampled(amount) != 3.75 ||
        $sampled(resolved_net) !== 1'b1)
      $fatal(1, "incorrect sample after the slot's first write or force");
    check_index(0);
    if ($sampled(plus_live(const'(value)) ^ plus_live(value)) !== (8'h68 ^ 8'h46))
      $fatal(1, "incorrect function argument, const cast, or callee value");
    -> mark;
    if (!$sampled(mark.triggered))
      $fatal(1, "event triggered property did not use its current value");

    #0;
    if ($sampled(value) !== 8'h12 || $sampled(words[2]) !== 4'h3 ||
        $sampled(resolved_net) !== 1'b1 || $sampled(amount) != 3.75)
      $fatal(1, "sample changed in the Inactive region");

    #1;
    value = 8'h56;
    clk = 1;
    release words[2];
    release resolved_net;
    release amount;
    if ($sampled(value) !== 8'h34 || $sampled(wide) !== 80'sh100 ||
        $sampled(words[2]) !== 4'h0 || $sampled(resolved_net) !== 1'b0 ||
        $sampled(amount) != 9.25)
      $fatal(1, "incorrect sample across release or time advance");

    #1;
    if (!action_checked || $sampled(cb.value) !== 8'h34 || $sampled(value) !== 8'h56)
      $fatal(1, "clocking input did not retain its most recent sample");
    $display("PASSED");
  end
`endif
endmodule

`ifndef ISSUE709_BAD_SKEW
interface issue709_sampled_bus;
  logic [7:0] data = 8'h12;
  logic [7:0] words [2:3];
endinterface

module issue709_sampled_sink(issue709_sampled_bus bus);
  int index = 2;
  initial begin
    bus.words[2] = 8'h56;
    #1;
    bus.data = 8'h34;
    bus.words[2] = 8'h78;
    index = 3;
    if ($sampled(bus.data) !== 8'h12 || $sampled(bus.words[index]) !== 8'h56)
      $fatal(1, "statically bound interface sampled the wrong storage or index");
  end
endmodule
`endif
