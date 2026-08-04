`begin_keywords "1800-2012"

package values_pkg;
  parameter int First  = 11;
  parameter int Second = 22;
endpackage

module child #(
  parameter int Values[2] = '{default: 0},
  parameter int Single = 0
) ();
  initial begin
    if (Values[0] !== 11 || Values[1] !== 22 || Single !== 11) begin
      $display("FAILED -- imported names in parameter pattern");
      $finish;
    end
  end
endmodule

module repeated_child #(
  parameter int Values[2] = '{default: 0}
) ();
  initial begin
    if (Values[0] !== 11 || Values[1] !== 11) begin
      $display("FAILED -- imported names in replicated parameter pattern");
      $finish;
    end
  end
endmodule

module main import values_pkg::*; ();
  localparam int Count = 2;

  child #(
    .Values('{First, Second}),
    .Single(First)
  ) explicit_pattern ();

  repeated_child #(
    .Values('{Count{First}})
  ) replicated_pattern ();

  initial begin
    #1;
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
