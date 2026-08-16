`timescale 1ns/1ps

module plain_wire(p); inout p; wire p; endmodule
module plain_tri0(p); inout p; tri0 p; endmodule
module plain_tri1(p); inout p; tri1 p; endmodule
module delay_tri0(p); inout p; tri0 #5 p; endmodule
module delay_tri1(p); inout p; tri1 #5 p; endmodule
module delay_supply0(p); inout p; supply0 #5 p; endmodule
module delay_supply1(p); inout p; supply1 #5 p; endmodule
module plain_supply0(p); inout p; supply0 p; endmodule
module plain_supply1(p); inout p; supply1 p; endmodule

// One lower-hierarchy net exposed through two port names.
module alias_tri0(.left(n), .right(n));
  inout n;
  tri0 n;
endmodule

module alias_tri1(.left(n), .right(n));
  inout n;
  tri1 n;
endmodule

module top;
  wire t0_first, t0_last, t1_first, t1_last;
  plain_tri0 t0a(t0_first); plain_wire w0a(t0_first);
  plain_wire w0b(t0_last); plain_tri0 t0b(t0_last);
  plain_tri1 t1a(t1_first); plain_wire w1a(t1_first);
  plain_wire w1b(t1_last); plain_tri1 t1b(t1_last);

  wire dt0_first, dt0_last, dt1_first, dt1_last;
  delay_tri0 dt0a(dt0_first); plain_wire dw0a(dt0_first);
  plain_wire dw0b(dt0_last); delay_tri0 dt0b(dt0_last);
  delay_tri1 dt1a(dt1_first); plain_wire dw1a(dt1_first);
  plain_wire dw1b(dt1_last); delay_tri1 dt1b(dt1_last);

  wire alias0_a, alias0_b, alias1_a, alias1_b;
  alias_tri0 aa0(alias0_a, alias0_b);
  alias_tri1 aa1(alias1_a, alias1_b);

  // Externally declared supply type/delay dominates every child in either
  // instance order. Opposite internal explicit pulls must be discarded.
  supply1 #3 ext_s1_a, ext_s1_b;
  supply0 #3 ext_s0_a, ext_s0_b;
  delay_supply0 es10(ext_s1_a); plain_wire es1w0(ext_s1_a);
  plain_wire es1w1(ext_s1_b); delay_supply0 es11(ext_s1_b);
  delay_supply1 es00(ext_s0_a); plain_wire es0w0(ext_s0_a);
  plain_wire es0w1(ext_s0_b); delay_supply1 es01(ext_s0_b);

  supply1 ext_plain_s1;
  supply0 ext_plain_s0;
  plain_supply0 ps10(ext_plain_s1);
  plain_supply1 ps01(ext_plain_s0);

  task automatic check(input logic got, input logic expected,
                       input string where);
    if (got !== expected) begin
      $display("FAILED %s t=%0t got=%b expected=%b", where, $time,
               got, expected);
      $fatal(1);
    end
  endtask

  initial begin
    #0.001 begin
      check(t0_first, 0, "tri0 first chained default");
      check(t0_last, 0, "tri0 last chained default");
      check(t1_first, 1, "tri1 first chained default");
      check(t1_last, 1, "tri1 last chained default");
      check(alias0_a, 0, "tri0 lower alias first port");
      check(alias0_b, 0, "tri0 lower alias second port");
      check(alias1_a, 1, "tri1 lower alias first port");
      check(alias1_b, 1, "tri1 lower alias second port");
      check(ext_plain_s1, 1, "undelayed external supply1 dominates");
      check(ext_plain_s0, 0, "undelayed external supply0 dominates");
      check(dt0_first, 1'bx, "delayed tri0 first initially x");
      check(dt0_last, 1'bx, "delayed tri0 last initially x");
      check(dt1_first, 1'bx, "delayed tri1 first initially x");
      check(dt1_last, 1'bx, "delayed tri1 last initially x");
    end
    #3 begin
      check(ext_s1_a, 1, "external supply1 first order");
      check(ext_s1_b, 1, "external supply1 last order");
      check(ext_s0_a, 0, "external supply0 first order");
      check(ext_s0_b, 0, "external supply0 last order");
    end
    #2 begin
      check(dt0_first, 0, "delayed tri0 first chained default");
      check(dt0_last, 0, "delayed tri0 last chained default");
      check(dt1_first, 1, "delayed tri1 first chained default");
      check(dt1_last, 1, "delayed tri1 last chained default");
    end
    $display("PASSED");
  end
endmodule
