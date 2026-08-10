// A value parameter can remain symbolic through more than one provisional
// class specialization.  In the generic outer pass, leaf#(K) must not be
// cached as the concrete value obtained by temporarily evaluating
// K=N+1 and N=M's declaration default.
class compound_leaf #(int V = 1);
  bit [V-1:0] payload;
endclass

class compound_inner #(int K = 1);
  typedef compound_leaf#(K) leaf_t;
  leaf_t leaf;
endclass

class compound_mid #(int N = 0);
  typedef compound_inner#(N + 1) inner_t;
  inner_t inner;
endclass

class compound_outer #(int M = 0);
  typedef compound_mid#(M) mid_t;
  mid_t mid;
endclass

module test;
  initial begin
    compound_outer#(2) small_obj;
    compound_outer#(7) large_obj;

    small_obj = new;
    small_obj.mid = new;
    small_obj.mid.inner = new;
    small_obj.mid.inner.leaf = new;

    large_obj = new;
    large_obj.mid = new;
    large_obj.mid.inner = new;
    large_obj.mid.inner.leaf = new;

    if ($bits(small_obj.mid.inner.leaf.payload) != 3)
      $fatal(1, "compound forwarding lost concrete M=2");
    if ($bits(large_obj.mid.inner.leaf.payload) != 8)
      $fatal(1, "compound forwarding lost concrete M=7");
    if (type(small_obj.mid.inner.leaf) == type(large_obj.mid.inner.leaf))
      $fatal(1, "distinct compound-forwarded values shared one class type");

    $display("PASSED");
  end
endmodule
