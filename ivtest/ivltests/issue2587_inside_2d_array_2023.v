// IEEE 1800-2017/2023 11.4.13: unpacked arrays in an inside set are
// recursively traversed to singular elements, including class properties.
class issue2587_two;
  bit [7:0] M [2][2] = '{'{8'd1, 8'd2}, '{8'd3, 8'd4}};
  rand bit [7:0] g;
  constraint c { g inside {M}; }
endclass

module issue2587_inside_2d_array;
  initial begin
    issue2587_two t;
    bit hit, miss;
    t = new;
    hit = 8'd3 inside {t.M};
    miss = 8'd5 inside {t.M};
    if (hit !== 1'b1 || miss !== 1'b0) $fatal(1, "inside membership failed");
    if (t.randomize() !== 1 || t.g < 1 || t.g > 4)
      $fatal(1, "inside constraint failed: g=%0d", t.g);
    $display("proc %0d %0d rc=1 g<=4 1", hit, miss);
  end
endmodule
