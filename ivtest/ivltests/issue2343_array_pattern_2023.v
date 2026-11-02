module top;
  typedef struct { int a; byte b; int c; } S;
  S s [0:1];
  int r [0:2] = '{7, 8, 9};
  int w [0:1][0:2];

  initial begin
    s = '{int: 5, default: 0};
    w = '{default: r};
    if (s[0].a !== 5 || s[0].b !== 0 || s[0].c !== 5 ||
        s[1].a !== 5 || s[1].b !== 0 || s[1].c !== 5)
      $fatal(1, "type-key/default struct pattern failed");
    if (w[0][0] !== 7 || w[0][1] !== 8 || w[0][2] !== 9 ||
        w[1][0] !== 7 || w[1][1] !== 8 || w[1][2] !== 9)
      $fatal(1, "whole-subarray default pattern failed");
    $display("PASS");
  end
endmodule
