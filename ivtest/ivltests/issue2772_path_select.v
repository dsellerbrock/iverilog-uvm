// IEEE 1800-2023 30.4.2/30.4.3: a module path terminal may be a bit- or
// part-select of a vector port. The path delays only the selected
// destination bits, and only the selected source bits trigger it.
`timescale 1ns/1ns

// The issue's case: y[1] has no path, so it changes without delay.
module p(input a, output [1:0] y);
  assign y = {a, a};
  specify (a *> y[0]) = 4; endspecify
endmodule

// Source selects: b[1] reaches z in 3, b[0] in 7.
module q(input [1:0] b, output z);
  assign z = ^b;
  specify
    (b[1] => z) = 3;
    (b[0] => z) = 7;
  endspecify
endmodule

// An indexed part select of an ascending vector, and a parallel path
// between part selects.
module r(input c, input [1:0] d, output [0:3] w, output [3:0] v);
  assign w = {4{c}};
  assign v = {d, d};
  specify
    (c *> w[1 +: 2]) = 5;
    (d[1:0] => v[3:2]) = 6;
  endspecify
endmodule

module issue2772_path_select;
  reg a = 0, c = 0;
  reg [1:0] b = 0, d = 0;
  wire [1:0] y;
  wire z;
  wire [0:3] w;
  wire [3:0] v;
  reg failed = 0;

  p up(a, y);
  q uq(b, z);
  r ur(c, d, w, v);

  task check(input [255:0] what, input [3:0] got, input [3:0] want);
    if (got !== want) begin
      $display("FAILED: %0s at %0t: got %b, want %b", what, $time, got, want);
      failed = 1;
    end
  endtask

  initial begin
    #10 a = 1;
    #1 check("y", y, 4'b0010);           // y[1] at once, y[0] waits
    #3 check("y", y, 4'b0011);           // 14
    #6 a = 0;                            // 20
    #1 check("y", y, 4'b0001);
    #3 check("y", y, 4'b0000);           // 24

    #6 b = 2'b10;                        // 30: b[1] path, 3
    #2 check("z", z, 4'b0000);
    #1 check("z", z, 4'b0001);           // 33
    #7 b = 2'b11;                        // 40: b[0] path, 7
    #3 check("z", z, 4'b0001);           // 43: not yet
    #3 check("z", z, 4'b0001);           // 46
    #1 check("z", z, 4'b0000);           // 47

    #3 c = 1;                            // 50: w[1:2] wait 5
    #1 check("w", w, 4'b1001);
    #4 check("w", w, 4'b1111);           // 55
    #5 d = 2'b01;                        // 60: v[3:2] wait 6
    #1 check("v", v, 4'b0001);
    #5 check("v", v, 4'b0101);           // 66
    if (!failed) $display("PASSED");
    $finish;
  end
endmodule
