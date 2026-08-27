// IEEE 1800-2017/2023 23.11: selected bind target instances retain
// generate/instance-array indices, and a bind inside a module resolves a
// hierarchical target relative to every instance of that module.
package bind_target_counts;
  localparam int SELECTED_LANE = 1;
  int hit_generate;
  int hit_array;
  int hit_relative;
  int errors;
endpackage

module bind_target_probe #(
  parameter int ID = 0,
  parameter int EXPECT = 0
) (input int observed);
  initial begin
    #0;
    case (ID)
      1: bind_target_counts::hit_generate =
           bind_target_counts::hit_generate + 1;
      2: bind_target_counts::hit_array =
           bind_target_counts::hit_array + 1;
      3: bind_target_counts::hit_relative =
           bind_target_counts::hit_relative + 1;
      default: bind_target_counts::errors =
                 bind_target_counts::errors + 1;
    endcase
    if (observed != EXPECT) begin
      bind_target_counts::errors = bind_target_counts::errors + 1;
      $display("FAILED: bind target %0d observed %0d, expected %0d",
               ID, observed, EXPECT);
    end
  end
endmodule

module bind_target_leaf #(parameter int TARGET_TAG = 0);
endmodule

module bind_target_holder;
  for (genvar i = 0; i < 3; i++) begin : lanes
    bind_target_leaf #(.TARGET_TAG(10+i)) child();
  end

  bind_target_leaf #(.TARGET_TAG(22)) children[3:1]();
endmodule

module bind_target_inner;
  bind_target_leaf #(.TARGET_TAG(31)) child();
endmodule

module bind_target_outer;
  // The local instance intentionally has the same name as its module type.
  // The second bind form resolves the instance before a module definition.
  bind_target_inner bind_target_inner();
  bind bind_target_inner.child bind_target_probe #(
    .ID(3), .EXPECT(31)
  ) relative_probe(.observed(TARGET_TAG));
endmodule

// This module is deliberately excluded by the selected top. Its valid
// relative bind must not become a false no-match error, nor attach globally.
module bind_target_excluded_owner;
  bind_target_leaf #(.TARGET_TAG(44)) child();
  bind child bind_target_probe #(
    .ID(99), .EXPECT(44)
  ) excluded_probe(.observed(TARGET_TAG));
endmodule

module sv_bind_indexed_relative_targets;
  bind_target_holder holder();
  bind_target_outer left();
  bind_target_outer right();

  initial begin
    #1;
    if (bind_target_counts::hit_generate == 1
        && bind_target_counts::hit_array == 1
        && bind_target_counts::hit_relative == 2
        && bind_target_counts::errors == 0)
      $display("PASSED");
    else
      $display("FAILED: counts %0d %0d %0d errors %0d",
               bind_target_counts::hit_generate,
               bind_target_counts::hit_array,
               bind_target_counts::hit_relative,
               bind_target_counts::errors);
  end
endmodule

bind sv_bind_indexed_relative_targets.holder.lanes[
  bind_target_counts::SELECTED_LANE
].child
  bind_target_probe #(.ID(1), .EXPECT(11)) generate_probe(
    .observed(TARGET_TAG)
  );

bind sv_bind_indexed_relative_targets.holder.children[2]
  bind_target_probe #(.ID(2), .EXPECT(22)) array_probe(
    .observed(TARGET_TAG)
  );
