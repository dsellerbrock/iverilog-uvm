// Legal IEEE 1800-2017 subarray contexts that remain intentionally loud.
// Keep these separate from illegal type/shape assignments so a generic
// compile failure cannot masquerade as evidence for the supported subset.
module class_member_destination_loud;
  class holder_t;
    logic [7:0] words [2];
  endclass
  holder_t holder;
  logic [7:0] src [2][2];
  initial begin
    holder = new;
    holder.words = src[0];
  end
endmodule

module class_property_prefix_source_loud;
  class holder_t;
    logic [7:0] words [1:0][2];
  endclass
  holder_t holder;
  logic [7:0] dst [2];
  initial begin
    holder = new;
    dst = holder.words[0];
  end
endmodule

module two_residual_dimensions_loud;
  logic [7:0] src [2][2][2];
  logic [7:0] dst [2][2];
  always_comb dst = src[0];
endmodule
