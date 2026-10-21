package A; enum {A,B,C=99} X; endpackage : A
import A::*;
module m; typedef struct {bit A,B;} S; S s; initial $display("S2 %0d", $bits(s)); endmodule
