// IEEE 1800-2017/2023 16.14.6.1: a Reactive action uses its instance's
// saved arguments, even if an earlier action blocks or the slot is reused.
module sva_proc_composite_order;
  bit root, clk1, clk2, request;
  bit a = 1, b = 1;
  int id;
  string actions = "", after_delay = "";

  property p;
    (@(posedge clk1) 1'b1 |-> a) and (@(posedge clk2) 1'b1 |-> b);
  endproperty

  task automatic record_entry(input int saved_id);
    actions = {actions, $sformatf(" P%0d", saved_id)};
  endtask

  task automatic record_pass(input int saved_id);
    record_entry(saved_id);
    actions = {actions, "!"};
    #12;
    after_delay = {after_delay, $sformatf(" P%0d", saved_id)};
  endtask

  always @(posedge request) begin
    automatic int saved_id = id;
    check_p: assert property (@(posedge root) (saved_id > 0) |=> p)
      record_pass(const'(id));
    else
      actions = {actions, $sformatf(" F%0d", saved_id)};
  end

  task automatic enqueue(input int queued_id);
    id = queued_id; request = 1;
    #1; request = 0; id = -1;
  endtask

  task automatic lead;
    root = 1; #1; root = 0;
  endtask

  initial begin
    #1;
    enqueue(1); lead();        // Slot 0
    clk2 = 1; #1; clk2 = 0;
    enqueue(2); lead();        // Slot 1
    clk1 = 1; #1; clk1 = 0;    // Attempt 1 passes and frees slot 0.
    if (actions != " P1!") $fatal(1, "first action:%s", actions);

    enqueue(3); lead();        // Reuses slot 0
    a = 0; #1;
    clk1 = 1; clk2 = 1;        // Attempt 2 passes and attempt 3 fails together.
    #1; clk1 = 0; clk2 = 0;
    if (actions != " P1! P2! F3") $fatal(1, "actions out of order:%s", actions);
    #24;
    if (after_delay != " P1 P2") $fatal(1, "incorrect delayed values:%s", after_delay);

    a = 1;
    enqueue(4); enqueue(-5); lead();
    // The negative value yields a vacuous pass on the root edge.
    if (actions != " P1! P2! F3 P-5!") $fatal(1, "incorrect saved antecedent:%s", actions);
    clk1 = 1; clk2 = 1; #1;
    if (actions != " P1! P2! F3 P-5! P4!") $fatal(1, "incorrect saved batch:%s", actions);
    $display("PASSED");
  end
endmodule
