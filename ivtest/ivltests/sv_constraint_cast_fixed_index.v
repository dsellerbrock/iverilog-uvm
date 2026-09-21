// IEEE 1800-2017/2023 6.24.1, 11.6 and 11.8.2: an index is
// self-determined, but still uses exact SV widths within that boundary.
class C;
  rand bit [7:0] a, b;
  bit invalid, impossible;
  bit [7:0] values[4] = '{9, 10, 77, 12};
  constraint c {
    a == 250; b == (invalid ? 18 : 10);
    int'(values[(a+b)/8'd2]) == (invalid ? 0 : 77);
    64'(values[(a+b)/8'd2]) == (invalid ? 0 : 77);
    if (impossible) a == 0;
  }
endclass
module test;
 C c = new;
 bit [7:0] old_a, old_b;
 string state_before;
 initial begin
   if (!c.randomize()) $fatal(1, "typed fixed index rejected");
   if (int'(c.values[(c.a+c.b)/8'd2]) != 77) $fatal(1, "ordinary index differs");
   c.invalid = 1;
   if (!c.randomize()) $fatal(1, "two-state invalid read rejected");
   if (c.values[(c.a+c.b)/8'd2] !== 0) $fatal(1, "invalid read mismatch");
   old_a=c.a; old_b=c.b; state_before=c.get_randstate();
   c.impossible=1;
   if (c.randomize()) $fatal(1, "contradiction accepted");
   if (c.a!==old_a || c.b!==old_b || c.get_randstate()!=state_before)
     $fatal(1, "failed solve changed values or RNG");
   $display("PASSED");
 end
endmodule
