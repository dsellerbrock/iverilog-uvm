// Array reduction methods over a random dynamic array or queue in a
// constraint (IEEE 1800-2017/2023 18.5.9, 7.12.3): the size is solved first,
// then the reduction folds the elements, truncated to the element type
// (8-bit sums wrap). Covers a class dynamic array, a queue, signed elements,
// product/and/or/xor, an empty array (identity values) and a local array in
// std::randomize ... with. These were reported as constraint items that are
// not representable (OpenTitan i2c transfer_lengths.sum()).
class cfg;
  rand int unsigned lens[];
  rand bit [7:0] q[$];
  rand int sgn[];
  rand bit [7:0] bits[];
  rand bit [7:0] none[];
  constraint k {
    lens.size() == 5;
    lens.sum() == 60;
    foreach (lens[i]) lens[i] inside {[3:30]};
    q.size() == 3;
    q.sum() == 8'd4;                  // wraps modulo 256
    sgn.size() == 4;
    sgn.sum() == -10;
    foreach (sgn[i]) sgn[i] inside {[-20:20]};
    bits.size() == 4;
    bits.or() == 8'hf0;
    bits.and() == 8'h30;
    bits.xor() == 8'h00;
    none.size() == 0;
    none.sum() == 0;
    none.and() == 8'hff;
  }
endclass

module main;
  int errors;
  initial begin
    cfg c;
    int unsigned local_lens[];
    bit [7:0] local_bytes[];
    bit ok;
    c = new;
    repeat (5) begin
      if (!c.randomize()) begin
        $display("FAILED randomize");
        errors++;
      end else begin
        if (c.lens.sum() !== 32'd60) begin $display("FAILED lens.sum %0d", c.lens.sum()); errors++; end
        if (c.q.sum() !== 8'd4) begin $display("FAILED q.sum %0d", c.q.sum()); errors++; end
        if (c.sgn.sum() !== -10) begin $display("FAILED sgn.sum %0d", c.sgn.sum()); errors++; end
        if (c.bits.or() !== 8'hf0 || c.bits.and() !== 8'h30 || c.bits.xor() !== 8'h00) begin
          $display("FAILED bits %h %h %h", c.bits.or(), c.bits.and(), c.bits.xor()); errors++;
        end
        if (c.lens.size() != 5 || c.q.size() != 3 || c.sgn.size() != 4 || c.none.size() != 0) begin
          $display("FAILED sizes"); errors++;
        end
        foreach (c.lens[i]) if (c.lens[i] < 3 || c.lens[i] > 30) begin $display("FAILED lens[%0d]", i); errors++; end
      end
    end
    repeat (5) begin
      ok = std::randomize(local_lens) with {
        local_lens.size() == 4;
        local_lens.sum() == 50;
        foreach (local_lens[i]) local_lens[i] inside {[5:25]};
      };
      if (!ok) begin $display("FAILED local randomize"); errors++; end
      else if (local_lens.sum() !== 32'd50) begin $display("FAILED local sum %0d", local_lens.sum()); errors++; end
      ok = std::randomize(local_bytes) with {
        local_bytes.size() == 3;
        local_bytes.sum() == 8'd1;
      };
      if (!ok) begin $display("FAILED local bytes randomize"); errors++; end
      else if (local_bytes.sum() !== 8'd1) begin $display("FAILED local bytes sum %0d", local_bytes.sum()); errors++; end
    end
    if (errors == 0) $display("PASSED");
  end
endmodule
