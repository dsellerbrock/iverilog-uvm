// M9-NFA LV-2: sequence local variable across a VARIABLE-length delay
// (IEEE 1800-2017 16.10) -- the legacy engine cannot store a
// per-attempt value across a window, so it sorries; the automaton
// engine gives each slot its own copy, captured when the assigning
// edge fires and compared at the (variable) read offset. Covers a
// bounded window, an unbounded wait, and an implication (the canonical
// outstanding-transaction pattern). Hand-computed counts.
module local_var_window_nfa_only;
  logic clk=0, a=0, b=0, req=0, ack=0;
  logic [7:0] d=0, c=0, tag=0, id=0;
  always #5 clk=~clk;

  // (1) bounded window: match at offset 1 and offset 3 with the captured value
  w1: cover property (@(posedge clk) (a, v = d) ##[1:3] (b && (c == v)));
  // (2) unbounded wait: capture then eventually match
  w2: cover property (@(posedge clk) (a, v = d) ##[1:$] (b && (c == v)));
  // (3) implication, unbounded: request tags, eventually ack with matching id
  w3: assert property (@(posedge clk) (req, t = tag) |-> ##[1:$] (ack && (id == t)))
        $display("W3 MATCH id=%h", id);

  initial begin
    // B1: capture A5; match at offset 1 -> w1++, w2++
    @(negedge clk) a=1; d=8'hA5;
    @(negedge clk) a=0; d=0; b=1; c=8'hA5;
    @(negedge clk) b=0; c=0;
    @(negedge clk);
    // B2: capture 33; c=99@1, 55@2, 33@3 -> w1++ (offset3), w2++ (offset3)
    @(negedge clk) a=1; d=8'h33;
    @(negedge clk) a=0; b=1; c=8'h99;
    @(negedge clk) c=8'h55;
    @(negedge clk) c=8'h33;
    @(negedge clk) b=0; c=0;
    @(negedge clk);
    // R1: request tag=AA; ack with id=AA after an unbounded wait -> W3 MATCH
    @(negedge clk) req=1; tag=8'hAA;
    @(negedge clk) req=0; tag=0;
    repeat(3) @(negedge clk);
    @(negedge clk) ack=1; id=8'hAA;
    @(negedge clk) ack=0; id=0;
    @(negedge clk);
    $display("w1=%0d w2=%0d (each expect 2)", _ivl_sva0_cnt0, _ivl_sva1_cnt0);
    $finish(0);
  end
endmodule
