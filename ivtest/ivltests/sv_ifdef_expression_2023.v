`define A
`define Y

module test;
  integer errors;
  ifdef_expr_library library_instance();

  initial begin
    errors = 0;

`ifdef (A || B && C)
`else
    errors = errors + 1;
`endif

`ifdef ((A || B) && C)
    errors = errors + 1;
`endif

`ifdef (A /* macro comment */ &&
        !B)
`else
    errors = errors + 1;
`endif

`ifdef (A -> B)
    errors = errors + 1;
`endif

`ifdef (A <-> A)
`else
    errors = errors + 1;
`endif

`ifndef (A && !B)
    errors = errors + 1;
`endif

`ifndef (!B && // line comment
         C)
`else
    errors = errors + 1;
`endif

`ifdef ((A && !B) || (B && C))
`ifdef (!C)
`else
    errors = errors + 1;
`endif
`else
    errors = errors + 1;
`endif

`ifdef (C)
    errors = errors + 1;
`elsif (A && !B)
`elsif (A)
    errors = errors + 1;
`else
    errors = errors + 1;
`endif

`ifdef (X -> Y <-> Z)
`else
    errors = errors + 1;
`endif

`ifdef ((X -> Y) <-> Z)
    errors = errors + 1;
`endif

`ifdef A
`else
    errors = errors + 1;
`endif

    if (errors == 0)
      $display("PASS");
    else
      $display("FAIL: %0d conditional-expression checks", errors);
  end
endmodule
