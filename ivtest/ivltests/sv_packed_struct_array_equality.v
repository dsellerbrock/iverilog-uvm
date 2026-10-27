// IEEE 1800-2023 §6.22.2(c), §11.4.5: equivalent packed structs and vectors
// compare bit by bit when size, state and signedness match.
module sv_packed_struct_array_equality;
  typedef struct packed { logic [3:0] a; logic [3:0] b; } ps_t;
  typedef struct packed { bit [3:0] a; bit [3:0] b; } ps2_t;
  ps_t P[0:1];
  logic [7:0] V[1:0];
  ps2_t P2[0:0];
  bit [7:0] V2[0:0];

  initial begin
    P[0]=8'hA5; P[1]=8'h5A;
    V[1]=8'hA5; V[0]=8'h5A;
    $display("packed struct/vector equal: eq=%b ceq=%b", P==V, P===V);
    V[1]=8'hA4;
    $display("packed struct/vector mismatch: eq=%b", P==V);
    V[1]=8'hA5; P[0].b=4'bx; V[1][3:0]=4'bx;
    $display("packed struct/vector X: eq=%b ceq=%b", P==V, P===V);
    P2[0]=8'hA5; V2[0]=8'hA5;
    $display("2-state packed struct/vector: eq=%b", P2==V2);
  end
endmodule
