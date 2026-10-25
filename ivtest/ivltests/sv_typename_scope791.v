package A;
  enum {A0, B0, C0=99} X;
endpackage

module sv_typename_scope791;
  typedef bit node;
  typedef struct {node P, Q;} AB_t;
  AB_t AB[10];

  initial begin
    if ($typename(A::X) != "enum{A0=32'sd0,B0=32'sd1,C0=32'sd99}A::e$1") begin
      $display("FAILED enum typename: %s", $typename(A::X));
      $finish(1);
    end
    if ($typename(AB) != "struct{bit P;bit Q;}sv_typename_scope791.AB_t$[0:9]") begin
      $display("FAILED struct typename: %s", $typename(AB));
      $finish(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
