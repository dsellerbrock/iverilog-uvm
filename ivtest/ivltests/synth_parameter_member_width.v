`begin_keywords "1800-2012"

module parameter_member_sink(
    input  logic [6:0] in_value,
    output logic [6:0] out_value
);
  assign out_value = in_value;
endmodule

module main;
  typedef struct packed {
    logic [20:0] padding;
    logic  [6:0] member;
  } parameter_t;

  localparam parameter_t PARAMETER = {21'h155555, 7'h53};

  wire [6:0]  port_value;
  wire [13:0] concatenated = {PARAMETER.member, PARAMETER.member};

  // The port expression must be sized as the selected 7-bit member, not as
  // the complete 28-bit parameter value.
  parameter_member_sink sink (
      .in_value  (PARAMETER.member),
      .out_value (port_value)
  );

  (* ivl_synthesis_off *)
  initial begin
    if ($bits(PARAMETER) != 28) begin
      $display("FAILED -- packed parameter width is %0d, expected 28",
               $bits(PARAMETER));
      $finish;
    end
    if ($bits(PARAMETER.member) != 7) begin
      $display("FAILED -- parameter member width is %0d, expected 7",
               $bits(PARAMETER.member));
      $finish;
    end
    if ($bits({PARAMETER.member, PARAMETER.member}) != 14) begin
      $display("FAILED -- concatenation width is %0d, expected 14",
               $bits({PARAMETER.member, PARAMETER.member}));
      $finish;
    end
    if (port_value !== 7'h53) begin
      $display("FAILED -- port value is %h, expected 53", port_value);
      $finish;
    end
    if (concatenated !== {7'h53, 7'h53}) begin
      $display("FAILED -- concatenated value is %h, expected %h",
               concatenated, {7'h53, 7'h53});
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
