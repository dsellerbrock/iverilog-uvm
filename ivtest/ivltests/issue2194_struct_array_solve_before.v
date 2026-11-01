// IEEE 1800-2017 18.5.10 / 1800-2023 18.5.9: an integral rand member
// selected through a fixed rand array of unpacked structs is orderable.
typedef struct { rand bit [3:0] v; } rec_t;

class c_t;
  rand rec_t recs[2];
  constraint k {
    recs[1].v < 8;
    solve recs[1].v before recs[0].v;
  }
endclass

module top;
  c_t c;
  initial begin
    c = new;
    repeat (32) begin
      if (!c.randomize()) $fatal(1, "struct-array solve-before failed");
      if (c.recs[1].v > 7) $fatal(1, "constraint was not enforced");
    end
    $display("PASS");
  end
endmodule
