module top;
  typedef struct packed { logic [3:0] a; logic [3:0] b; } ps_t;
  typedef struct packed { bit [3:0] a; bit [3:0] b; } ps2_t;
  ps_t P; logic [7:0] V; ps2_t P2; bit [7:0] V2;
  initial begin
    P=8'hA5; V=8'hA5; P2=8'hA5; V2=8'hA5;
    $display("pstruct equal: eq=%b ceq=%b (expect 1 1)",P==V,P===V);
    V=8'hA4; $display("pstruct mismatch: eq=%b (expect 0)",P==V);
    V=8'hA5; P.b=4'bx; V[3:0]=4'bx; $display("pstruct x: eq=%b ceq=%b (expect x 1)",P==V,P===V);
    $display("2-state pstruct: eq=%b (expect 1)",P2==V2);
  end
endmodule
