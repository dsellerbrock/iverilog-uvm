// `expect' (16.17) beyond fixed chains: windows, unbounded waits, goto
// repetition, and sequence-or trees ride the automaton engine as a
// single inline attempt driven by the blocking process. The legacy
// engine diagnoses these shapes with a sorry.
module expect_general_nfa_only;
  bit clk = 0, b = 0, c = 0;
  always #5 clk = ~clk;
  initial begin
    // window pass: b rises within [1:3] ticks
    fork begin #22 b = 1; #10 b = 0; end join_none
    expect (@(posedge clk) 1 ##[1:3] b) $display("T1 pass");
    else $display("T1 fail");
    // window fail: nothing rises
    expect (@(posedge clk) 1 ##[1:2] c) $display("T2 pass");
    else $display("T2 fail");
    // unbounded wait resolving late
    fork begin #37 c = 1; #10 c = 0; end join_none
    expect (@(posedge clk) 1 ##[1:$] c) $display("T3 pass");
    else $display("T3 fail");
    // goto repetition: second occurrence of b
    b = 0;
    fork begin #12 b = 1; #10 b = 0; #10 b = 1; #10 b = 0; end join_none
    expect (@(posedge clk) 1 ##1 b [->2]) $display("T4 pass");
    else $display("T4 fail");
    // sequence-or tree: the c branch matches first
    b = 0; c = 0;
    fork begin #22 c = 1; end join_none
    expect (@(posedge clk) (1 ##1 b) or (1 ##2 c)) $display("T5 pass");
    else $display("T5 fail");
    $finish(0);
  end
endmodule
