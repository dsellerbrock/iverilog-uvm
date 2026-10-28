module t;
  typedef int arr_t[2];
  typedef int mat_t[2][2];
  typedef struct packed { logic [3:0] a; logic [3:0] b; } ps_t;
  typedef struct packed { bit [3:0] a; bit [3:0] b; } ps2_t;
  arr_t A; mat_t M; ps_t P; logic [7:0] V; ps2_t P2; bit [7:0] V2;
  initial begin
    A='{1,2}; M='{'{1,2},'{3,4}};
    $display("typed arr   eq=%b ne=%b ceq=%b (exp 1 0 1)", A==arr_t'{1,2}, A!=arr_t'{1,2}, A===arr_t'{1,2});
    $display("typed arr 3 eq=%b (exp 1)", A!==arr_t'{1,2});
    $display("typed arr 2 eq=%b ne=%b (exp 0 1)", A==arr_t'{1,3}, A!=arr_t'{1,3});
    $display("typed mat   eq=%b (exp 1)", M==mat_t'{'{1,2},'{3,4}});
    $display("typed mat 2 eq=%b (exp 0)", M==mat_t'{'{1,2},'{3,5}});
    $display("typed def   eq=%b (exp 0)", A==arr_t'{default:0});
    P=8'hA5; V=8'hA5; P2=8'hA5; V2=8'hA5;
    $display("pstruct eq=%b ceq=%b (exp 1 1)", P==V, P===V);
    V=8'hA4; $display("pstruct ne eq=%b (exp 0)", P==V);
    V=8'hA5; P.b=4'bx; V[3:0]=4'bx; $display("pstruct x eq=%b ceq=%b (exp x 1)", P==V, P===V);
    $display("2-state eq=%b (exp 1)", P2==V2);
  end
endmodule
