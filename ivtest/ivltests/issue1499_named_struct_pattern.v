typedef struct packed {
  bit [3:0] tag;
  bit [3:0] payload;
  bit [3:0] spare;
} msg_t;

module top;
  msg_t value = 12'hA53;
  int result;

  initial begin
    // Named structure pattern members can appear in a different order.
    case (value) matches
      '{payload:.p, tag:4'hA}: result = p;
      default: result = -1;
    endcase
    if (result !== 5) $fatal(1, "named reordered result=%0d", result);

    // Members omitted from a named structure pattern are not matched.
    value.spare = 4'hF;
    case (value) matches
      '{tag:4'hA, payload:.p}: result = p;
      default: result = -1;
    endcase
    if (result !== 5) $fatal(1, "named partial result=%0d", result);
    $display("PASS");
  end
endmodule
