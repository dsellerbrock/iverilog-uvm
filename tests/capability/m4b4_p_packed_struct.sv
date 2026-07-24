module top;
  typedef struct packed { bit [3:0] a; bit [3:0] b; } ps_t;
  ps_t s; string r;
  initial begin s.a=4'h1; s.b=4'h2; r=$sformatf("%p",s);
    if (r=="'{a:1, b:2}") $display("PASS"); else $display("FAIL got %0s",r); $finish(0); end
endmodule
