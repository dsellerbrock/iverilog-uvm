`begin_keywords "1800-2012"

module implicit_param_leaf #(
  parameter int Width = 1
) (
  output logic [Width-1:0] value
);
  assign value = '1;
endmodule

module implicit_param_probe #(
  parameter int First = 0,
  parameter int Second = 0
) ();
  initial begin
    if (First != 7 || Second != 9) begin
      $display("FAILED -- bound shorthand values were %0d and %0d",
               First, Second);
      $finish;
    end
  end
endmodule

module implicit_param_target #(
  parameter int First = 7,
  parameter int Second = 9
) ();
endmodule

// A bind parameter override is elaborated in the target scope. OpenTitan's
// OTBN trace interface uses this implicit named parameter assignment form.
bind implicit_param_target implicit_param_probe #(
  .First,
  .Second
) probe ();

module main;
  localparam int Width = 5;
  logic [Width-1:0] value;

  implicit_param_leaf #(.Width) leaf (value);
  implicit_param_target target ();

  initial begin
    #1;
    if (value !== 5'b11111) begin
      $display("FAILED -- module shorthand value was %b", value);
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
