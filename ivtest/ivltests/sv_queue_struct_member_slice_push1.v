module test;
  typedef logic [31:0] data_t;
  typedef struct {
    data_t data;
    int n_bits;
  } item_t;

  initial begin
    item_t accesses[$];
    byte p[$];
    item_t item;

    item.data = 32'h44332211;
    item.n_bits = 32;
    accesses.push_back(item);

    foreach (accesses[i0]) begin
      for (int i1 = 0; i1 < 4; i1++) begin
        p.push_back(accesses[i0].data[i1*8+:8]);
      end
    end

    if (p.size() != 4) begin
      $display("FAIL size=%0d", p.size());
      $finish(1);
    end

    if (p[0] != 8'h11 || p[1] != 8'h22 || p[2] != 8'h33 || p[3] != 8'h44) begin
      $display("FAIL vals %02x %02x %02x %02x", p[0], p[1], p[2], p[3]);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
