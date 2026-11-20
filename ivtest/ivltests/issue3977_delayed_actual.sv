`timescale 1ns/1ns
module issue3977_delayed_actual;
  bit clk, a, b, c;
  bit prefix, chain_a, chain_b, suffix, chain_c;
  always #5 clk = !clk;

  bit [31:0] passes[10], failures[10];
  time pass_tick[10], fail_tick[10];

  task automatic passed(int index);
    passes[index]++;
    pass_tick[index] = $time;
  endtask

  task automatic failed(int index);
    failures[index]++;
    fail_tick[index] = $time;
  endtask

  function automatic bit identity(bit value);
    return value;
  endfunction

  // A forward reference has the same argument grammar as a known property.
  positional: assert property (p(a ##1 b)) passed(0); else failed(0);

  property p(sequence s);
    @(posedge clk) s |-> c;
  endproperty

  property with_default(sequence s = a ##1 b);
    @(posedge clk) s |-> c;
  endproperty

  property forward(sequence s);
    p(s);
  endproperty

  property in_chain(sequence s);
    @(posedge clk) prefix ##1 s ##1 suffix |-> chain_c;
  endproperty

  property with_local(sequence s);
    int a = 0;
    @(posedge clk) s |-> (!a && c);
  endproperty

  property twice(sequence s);
    @(posedge clk) s ##1 s |-> c;
  endproperty

  direct: assert property (@(posedge clk) (a ##1 b) |-> c)
    passed(1); else failed(1);
  named_actual: assert property (p(.s((identity(identity((a))) ##1 (b)))))
    passed(2); else failed(2);
  forwarded: assert property (forward(a ##1 b))
    passed(3); else failed(3);
  spliced: assert property (in_chain(chain_a ##1 chain_b))
    passed(4); else failed(4);
  direct_chain: assert property (
    @(posedge clk) prefix ##1 chain_a ##1 chain_b ##1 suffix |-> chain_c)
    passed(5); else failed(5);
  shadowed: assert property (with_local(a ##1 b)) passed(8); else failed(8);
  reused: assert property (twice(a ##1 b)) passed(9); else failed(9);

  if (1) begin : inner
    bit a, b;
    // The default sees module a/b, while the forwarded actual sees inner a/b.
    defaulted: assert property (with_default(.s())) passed(6); else failed(6);
    caller_bound: assert property (forward(a ##1 b)) passed(7); else failed(7);
    initial begin
      #21 a = 1;
      #10 a = 0; b = 1;
      #10 b = 0;
    end
  end

  initial begin
    $assertvacuousoff(0);
    #1  a = 1; prefix = 1;
    #10 a = 0; b = 1; prefix = 0; chain_a = 1;
    #10 a = 1; b = 0; prefix = 1; chain_a = 0; chain_b = 1;
    #10 a = 0; b = 1; c = 1; prefix = 0; chain_a = 1; chain_b = 0; suffix = 1;
    #10 b = 0; c = 0; chain_a = 0; chain_b = 1; suffix = 0;
    #10 chain_b = 0; suffix = 1; chain_c = 1;
    #8;
    for (int i = 0; i < 10; i++) begin
      if (passes[i] !== 1 || pass_tick[i] !== ((i == 4 || i == 5) ? 55 : 35))
        $fatal(1, "case %0d: pass count=%0d tick=%0d", i, passes[i], pass_tick[i]);
      if (i == 7 || i == 9) begin
        if (failures[i] !== 0)
          $fatal(1, "case %0d: unexpected failure at %0d", i, fail_tick[i]);
      end else if (failures[i] !== 1 || fail_tick[i] !== ((i == 4 || i == 5) ? 35 : 15))
        $fatal(1, "case %0d: fail count=%0d tick=%0d", i, failures[i], fail_tick[i]);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
