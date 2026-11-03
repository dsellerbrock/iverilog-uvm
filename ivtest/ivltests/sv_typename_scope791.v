package A;
  enum {A, B, C=99} X;
endpackage : A

module top;
  typedef bit node;
  typedef struct {node P, Q;} AB_t;
  AB_t AB[10];

  initial begin
    if ($typename(A::X) !=
	"enum{A=32'sd0,B=32'sd1,C=32'sd99}A::e$1") begin
      $display("FAILED enum typename: %s", $typename(A::X));
      $finish(1);
    end
    if ($typename(AB) != "struct{bit P;bit Q;}top.AB_t$[0:9]") begin
      $display("FAILED struct typename: %s", $typename(AB));
      $finish(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
