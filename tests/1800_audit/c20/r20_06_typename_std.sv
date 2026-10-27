typedef bit node;
node [2:0] X;
int signed Y;
package A; enum {A,B,C=99} X; typedef bit [9:1'b1] word; endpackage : A
import A::*;
module top();
  typedef struct {node A,B;} AB_t;
  AB_t AB[10];
  A::word W;
  initial begin
    $display("T1 [%s]", $typename(X));
    $display("T2 [%s]", $typename(Y));
    $display("T3 [%s]", $typename(A::X));
    $display("T4 [%s]", $typename(W));
    $display("T5 [%s]", $typename(AB));
  end
endmodule
