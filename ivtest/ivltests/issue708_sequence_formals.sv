// IEEE 1800-2017/2023 16.8 / 16.8.1: typed sequence formals cast their
// actuals, a type applies to the following formals up to the next type,
// `untyped' ends it, a formal may have a default actual, and a `sequence'
// formal accepts a Boolean actual.
module issue708_sequence_formals;
  bit clk = 0;
  always #5 clk = ~clk;
  logic [3:0] w = 4'b0111, z = 4'b1011;
  bit a = 1;
  int pass_trunc = 0, fail_trunc = 0, pass_def = 0, fail_def = 0;
  int pass_inh = 0, fail_inh = 0, pass_unt = 0, fail_unt = 0;
  int pass_seq = 0, fail_seq = 0, pass_named = 0, fail_named = 0;

  sequence s_trunc(bit [1:0] v);       // 4'b0111 -> 2'b11
    v == 2'b11;
  endsequence
  sequence s_def(x, y = 1'b1);
    x ##1 y;
  endsequence
  sequence s_inh(bit [1:0] p, q);      // q is bit [1:0] too
    p == q;
  endsequence
  sequence s_unt(bit [1:0] p, untyped q);
    p == q;
  endsequence
  sequence s_sq(sequence q);
    q;
  endsequence

  a1: assert property (@(posedge clk) s_trunc(w)) pass_trunc++; else fail_trunc++;
  a2: assert property (@(posedge clk) s_def(a)) pass_def++; else fail_def++;
  a3: assert property (@(posedge clk) s_inh(w, z)) pass_inh++; else fail_inh++;
  a4: assert property (@(posedge clk) s_unt(w, w)) pass_unt++; else fail_unt++;
  a5: assert property (@(posedge clk) s_sq(a)) pass_seq++; else fail_seq++;
  a6: assert property (@(posedge clk) s_def(.y(a), .x(a))) pass_named++; else fail_named++;

  initial begin
    #42;
    if (pass_trunc == 4 && fail_trunc == 0 && pass_def == 3 && fail_def == 0
        && pass_inh == 4 && fail_inh == 0 && pass_unt == 0 && fail_unt == 4
        && pass_seq == 4 && fail_seq == 0 && pass_named == 3 && fail_named == 0)
      $display("PASSED");
    else
      $display("FAILED: %0d/%0d %0d/%0d %0d/%0d %0d/%0d %0d/%0d %0d/%0d",
               pass_trunc, fail_trunc, pass_def, fail_def, pass_inh, fail_inh,
               pass_unt, fail_unt, pass_seq, fail_seq, pass_named, fail_named);
    $finish;
  end
endmodule
