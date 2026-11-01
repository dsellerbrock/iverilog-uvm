// A randomized index gives the bit-select dist subject two rand leaves.
// The joint solver must preserve the subject's weighted distribution.
class csrng_index_leaf;
  rand bit seen;
endclass

class csrng_index_root;
  rand csrng_index_leaf child;
  rand bit [2:0] read_enable;
  rand bit [1:0] index;

  function new;
    child = new;
  endfunction

  constraint indexed_c {
    index inside {[0:2]};
    read_enable[index] dist {1'b1 :/ 3, 1'b0 :/ 1};
    child.seen == read_enable[0];
  }
endclass

typedef struct packed { bit [1:0] mode; bit en; } csrng_dist_packet_t;

class csrng_struct_root;
  rand csrng_index_leaf child;
  rand csrng_dist_packet_t packet;

  function new;
    child = new;
  endfunction

  constraint packet_c {
    packet.mode dist {2'd1 :/ 3, 2'd0 :/ 1};
    child.seen == packet.en;
  }
endclass

module csrng_packed_bit_joint_dist_multileaf;
  initial begin
    csrng_index_root cfg;
    csrng_struct_root struct_cfg;
    int ones;
    cfg = new;
    cfg.srandom(32'h2030);
    cfg.child.srandom(32'h2031);
    ones = 0;
    repeat (128) begin
      if (!cfg.randomize())
        $fatal(1, "multi-leaf projected dist randomize failed");
      if (cfg.read_enable[cfg.index] !== 1'b0 &&
          cfg.read_enable[cfg.index] !== 1'b1)
        $fatal(1, "selected bit is not binary");
      ones += cfg.read_enable[cfg.index];
      if (cfg.child.seen !== cfg.read_enable[0])
        $fatal(1, "nested rand constraint was not satisfied");
    end
    if (ones < 76 || ones > 116)
      $fatal(1, "multi-leaf projected dist weight lost: %0d/128", ones);

    struct_cfg = new;
    struct_cfg.srandom(32'h2032);
    struct_cfg.child.srandom(32'h2033);
    ones = 0;
    repeat (128) begin
      if (!struct_cfg.randomize())
        $fatal(1, "packed struct member dist randomize failed");
      if (struct_cfg.packet.mode !== 2'd0 &&
          struct_cfg.packet.mode !== 2'd1)
        $fatal(1, "packed struct member dist selected an excluded value");
      ones += (struct_cfg.packet.mode == 2'd1);
      if (struct_cfg.child.seen !== struct_cfg.packet.en)
        $fatal(1, "nested rand packed struct constraint was not satisfied");
    end
    if (ones < 76 || ones > 116)
      $fatal(1, "packed struct member dist weight lost: %0d/128", ones);
    $display("PASS multi-leaf projected dist weighting");
  end
endmodule
