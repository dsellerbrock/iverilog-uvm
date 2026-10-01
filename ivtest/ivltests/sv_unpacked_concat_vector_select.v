// Items of an unpacked-array concatenation that are selects of a packed
// vector, {q, addr[23:16], addr[15:8]}, are packed selects of that vector.
// In the typed container context the bracket was taken for a missing array
// index and dropped, so every item became the whole vector truncated to the
// element width: {q, a[23:16], a[15:8], a[7:0]} appended three copies of
// a[7:0] (OpenTitan spi_device flash address bytes).
module main;
  int errors;

  task automatic expect_q(string what, bit [7:0] got[$], bit [7:0] want[$]);
    if (got.size() != want.size()) begin
      $display("FAILED %s size %0d want %0d", what, got.size(), want.size()); errors++;
    end else foreach (want[i]) if (got[i] !== want[i]) begin
      $display("FAILED %s[%0d]=%h want %h", what, i, got[i], want[i]); errors++;
    end
  endtask

  initial begin
    automatic bit [31:0] addr = 32'hA1B2C3D4;
    automatic bit [7:0] q[$];
    automatic bit [7:0] da[];
    automatic bit bits[$];
    automatic bit [15:0] words[$];
    automatic bit [3:0][7:0] packed2 = 32'h04030201;
    automatic int lane = 2;

    q.push_back(addr[31:24]);
    q = {q, addr[23:16], addr[15:8], addr[7:0]};
    expect_q("queue part selects", q, '{8'hA1, 8'hB2, 8'hC3, 8'hD4});

    q = {addr[15:8], addr[31:24]};
    expect_q("queue reordered", q, '{8'hC3, 8'hA1});

    q = '{};
    q = {q, addr[8*lane +: 8], addr[8*1 +: 8]};
    expect_q("queue indexed part select", q, '{8'hB2, 8'hC3});

    da = {addr[23:16], addr[7:0]};
    if (da.size() != 2 || da[0] !== 8'hB2 || da[1] !== 8'hD4) begin
      $display("FAILED dynamic array concat %p", da); errors++;
    end

    bits = {addr[31], addr[0], addr[3]};
    if (bits.size() != 3 || bits[0] !== 1'b1 || bits[1] !== 1'b0 || bits[2] !== 1'b0) begin
      $display("FAILED bit selects %p", bits); errors++;
    end

    words = {addr[31:16], addr[15:0]};
    if (words.size() != 2 || words[0] !== 16'hA1B2 || words[1] !== 16'hC3D4) begin
      $display("FAILED word selects %p", words); errors++;
    end

    q = {packed2[1], packed2[3]};
    expect_q("packed 2-D element selects", q, '{8'h02, 8'h04});

    if (errors == 0) $display("PASSED");
  end
endmodule
