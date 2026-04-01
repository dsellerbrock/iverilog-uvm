module test;
  typedef struct {
    logic [31:0] data;
    int n_bits;
  } item_t;

  initial begin
    item_t item;

    item.data = 32'h44332211;
    item.n_bits = 32;

    if (item.data !== 32'h44332211 || item.n_bits !== 32) begin
      $display("FAIL data=%08x n_bits=%0d", item.data, item.n_bits);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
