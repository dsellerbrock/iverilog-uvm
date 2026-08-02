// IEEE 1800-2017 16.9.2: ##[*] and ##[+] abbreviate the unbounded
// cycle-delay ranges ##[0:$] and ##[1:$]. OpenTitan uses ##[+] inside
// first_match() as an assertion antecedent.
module sva_unbounded_delay_shorthand_test;
  logic clk = 0;
  logic pd = 1;
  logic channel = 1;
  always #5 clk = ~clk;

  property enter_low_power_p;
    first_match($fell(pd) ##[+] $fell(channel)) |=> ##[0:3] pd;
  endproperty

  a_enter: assert property (@(posedge clk) enter_low_power_p);
  c_star: cover property (@(posedge clk) $fell(pd) ##[*] $fell(channel));

  initial begin
    repeat (2) @(negedge clk);
    $display("SVA UNBOUNDED DELAY SHORTHAND TEST: PASS");
    $finish(0);
  end
endmodule
