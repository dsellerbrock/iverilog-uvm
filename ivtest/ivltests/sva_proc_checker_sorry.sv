// IEEE 1800-2023 17.3 places a checker's static deferred assertions, and its
// static concurrent assertions through named properties, at a procedural
// instance. Neither is done yet; both must be refused, never dropped. So are
// a name the checker reads from $unit that is declared again nearer the
// instance (it would rebind), and an assertion the checker lowers only at
// its end (a sequence declared after it), whose items escape the record.
int g = 1;

checker with_deferred(event clk, logic a);
  d: assert #0 (a);
  p: assert property (@clk a);
endchecker

checker with_property(event clk, logic a);
  property hold(logic x);
    x;
  endproperty
  p: assert property (@clk hold(a));
endchecker

checker reads_g(event clk);
  p: assert property (@clk g == 1);
endchecker

checker late_sequence(event clk, logic a);
  p: assert property (@clk s1);
  sequence s1;
    a;
  endsequence
endchecker

module top;
  logic clk = 0, a = 0;
  int g = 0;
  always @(posedge clk) begin
    with_deferred d1(posedge clk, a);
    with_property n1(posedge clk, a);
    reads_g r1(posedge clk);
    late_sequence l1(posedge clk, a);
  end
endmodule
