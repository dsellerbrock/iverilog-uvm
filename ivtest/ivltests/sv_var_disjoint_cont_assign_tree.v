// Continuous assignments to disjoint bits of one variable are legal (IEEE
// 1800-2017/2023 6.5), as in OpenTitan prim_onehot_check's reduction trees.
// The code generator warned that the variable was a multi-driven uwire
// "treated as wire" for every such tree; the gold pins an empty compiler
// log.
module test;
  localparam int N = 3;
  logic [2**N-1:0] oh = 8'b0010_0000;
  logic [2**(N+1)-2:0] or_tree;
  for (genvar level = 0; level < N+1; level++) begin : gen_tree
    localparam int Base0 = (2**level)-1;
    localparam int Base1 = (2**(level+1))-1;
    for (genvar offset = 0; offset < 2**level; offset++) begin : gen_level
      localparam int Pa = Base0 + offset;
      localparam int C0 = Base1 + 2*offset;
      localparam int C1 = Base1 + 2*offset + 1;
      if (level == N) begin : gen_leaf
        assign or_tree[Pa] = oh[offset];
      end else begin : gen_node
        assign or_tree[Pa] = or_tree[C0] || or_tree[C1];
      end
    end
  end
  initial begin
    #1 if (or_tree[0] !== 1'b1) $display("FAILED: %b", or_tree);
    oh = 0;
    #1 if (or_tree[0] !== 1'b0) $display("FAILED: %b", or_tree);
    else $display("PASSED");
  end
endmodule
