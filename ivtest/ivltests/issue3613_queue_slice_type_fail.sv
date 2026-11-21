class holder_t;
  bit [7:0] values[2];
endclass

module test;
  bit [7:0] bits[2];
  logic signed [7:0] signed_values[2];
  logic [7:0] queue[$];
  holder_t holder;

  initial begin
    holder = new;
    queue = bits[0:1];
    queue = signed_values[0:1];
    queue = holder.values[0:1];
  end
endmodule
