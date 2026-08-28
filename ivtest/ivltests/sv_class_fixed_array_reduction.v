// IEEE 1800-2017 7.12.3: reduction methods apply to one-dimensional
// fixed unpacked arrays reached through class properties. The receiver is
// evaluated once, the with expression once per element, result width/sign
// follow the element or with expression, and iterator.index() is a declared
// (not canonical storage) index.
class fixed_reduction_holder;
  logic signed [7:0] signed_values[4:1];
  logic        [7:0] indexed_values[4:1];
  logic        [7:0] direction_values[4:1];
  logic        [7:0] factors[-2:1];
  logic        [7:0] masks[7:4];
  logic        [3:0] unknowns[0:1];
endclass

module main;
  fixed_reduction_holder holder;
  logic [7:0] direct_descending[4:1];
  logic [7:0] direct_ascending[1:4];
  int receiver_calls;
  int value_calls;
  bit failed;

  function fixed_reduction_holder get_holder;
    receiver_calls = receiver_calls + 1;
    return holder;
  endfunction

  function automatic logic signed [15:0] counted_wide(
      input logic [7:0] value);
    value_calls = value_calls + 1;
    return 16'(value);
  endfunction

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  initial begin
    logic signed [7:0] signed_sum;
    logic signed [15:0] wide_sum;
    int indexed_sum;

    failed = 1'b0;
    holder = new;

    holder.signed_values[1] = 8'sd100;
    holder.signed_values[2] = 8'sd100;
    holder.signed_values[3] = 8'sd100;
    holder.signed_values[4] = 8'sd100;
    signed_sum = holder.signed_values.sum();
    check("plain result width", $bits(holder.signed_values.sum()) == 8);
    check("plain result sign and modular width", signed_sum === -8'sd112);

    holder.indexed_values[1] = 8'd1;
    holder.indexed_values[2] = 8'd2;
    holder.indexed_values[3] = 8'd3;
    holder.indexed_values[4] = 8'd4;
    check("paren-less class-property reduction",
          holder.indexed_values.sum == 8'd10);

    receiver_calls = 0;
    indexed_sum = get_holder().indexed_values.sum(entry)
                  with (entry * entry.index());
    check("arbitrary receiver evaluated once", receiver_calls == 1);
    check("declared descending nonzero indexes", indexed_sum == 30);

    holder.direction_values[4] = 8'd1;
    holder.direction_values[3] = 8'd2;
    holder.direction_values[2] = 8'd4;
    holder.direction_values[1] = 8'd8;
    indexed_sum = holder.direction_values.sum(entry)
                  with (entry * entry.index());
    check("materialized descending property pairs values with declared indexes",
          indexed_sum == 26);

    direct_descending[4] = 8'd1;
    direct_descending[3] = 8'd2;
    direct_descending[2] = 8'd4;
    direct_descending[1] = 8'd8;
    indexed_sum = direct_descending.sum(entry)
                  with (entry * entry.index());
    check("direct descending signal pairs values with declared indexes",
          indexed_sum == 26);

    direct_ascending[1] = 8'd1;
    direct_ascending[2] = 8'd2;
    direct_ascending[3] = 8'd4;
    direct_ascending[4] = 8'd8;
    indexed_sum = direct_ascending.sum(entry)
                  with (entry * entry.index());
    check("direct ascending signal pairs values with declared indexes",
          indexed_sum == 49);

    value_calls = 0;
    check("$bits does not evaluate with expression",
          $bits(holder.indexed_values.sum(value)
                with (counted_wide(value))) == 16
          && value_calls == 0);
    wide_sum = holder.indexed_values.sum(value)
               with (counted_wide(value));
    check("with expression evaluated once per element", value_calls == 4);
    check("with expression controls result width", wide_sum == 16'sd10);

    holder.factors[-2] = 8'd2;
    holder.factors[-1] = 8'd3;
    holder.factors[0] = 8'd4;
    holder.factors[1] = 8'd5;
    check("product", holder.factors.product() == 8'd120);

    holder.masks[4] = 8'hf3;
    holder.masks[5] = 8'hcf;
    holder.masks[6] = 8'h0f;
    holder.masks[7] = 8'hff;
    check("and", holder.masks.and() == 8'h03);
    check("or", holder.masks.or() == 8'hff);
    check("xor", holder.masks.xor() == 8'hcc);

    holder.unknowns[0] = 4'h1;
    holder.unknowns[1] = 4'hx;
    check("four-state elements retain unknowns",
          $isunknown(holder.unknowns.sum()));

    if (failed)
      $fatal(1, "fixed-array class-property reduction checks failed");
    $display("PASSED");
  end
endmodule
