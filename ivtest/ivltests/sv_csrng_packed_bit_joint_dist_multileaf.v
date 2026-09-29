// A randomized index gives the bit-select dist subject two rand leaves.
// The one-leaf joint projection path must reject it.
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

module csrng_packed_bit_joint_dist_multileaf;
  initial begin
    csrng_index_root cfg;
    cfg = new;
    if (cfg.randomize())
      $fatal(1, "multi-leaf projected dist was silently accepted");
    $display("PASS multi-leaf projected dist rejected");
  end
endmodule
