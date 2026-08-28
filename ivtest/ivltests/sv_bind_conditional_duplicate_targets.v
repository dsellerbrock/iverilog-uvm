// IEEE 1800-2017/2023 23.6/23.11: a bind target path can traverse
// same-named conditional-generate alternatives when they reach the same
// module definition. Only the elaborated alternative receives the bound
// instance. A final unselected instance-array component names every element.
package bind_duplicate_counts;
  int hit_if;
  int hit_else;
  int hit_array;
  int errors;
endpackage

module bind_duplicate_probe #(
  parameter int ID = 0,
  parameter int EXPECT = 0
) (input int observed);
  initial begin
    #0;
    case (ID)
      1: bind_duplicate_counts::hit_if =
           bind_duplicate_counts::hit_if + 1;
      2: bind_duplicate_counts::hit_else =
           bind_duplicate_counts::hit_else + 1;
      3: bind_duplicate_counts::hit_array =
           bind_duplicate_counts::hit_array + 1;
      default: bind_duplicate_counts::errors =
                 bind_duplicate_counts::errors + 1;
    endcase
    if (observed != EXPECT) begin
      bind_duplicate_counts::errors =
        bind_duplicate_counts::errors + 1;
      $display("FAILED: bind target %0d observed %0d, expected %0d",
               ID, observed, EXPECT);
    end
  end
endmodule

module bind_duplicate_leaf #(parameter int TARGET_TAG = 0);
endmodule

module bind_duplicate_same_holder #(parameter bit TAKE_IF = 1'b1);
  if (TAKE_IF) begin : selected
    bind_duplicate_leaf #(.TARGET_TAG(11)) child();
  end else begin : selected
    bind_duplicate_leaf #(.TARGET_TAG(12)) child();
  end
endmodule

module sv_bind_conditional_duplicate_targets;
  bind_duplicate_same_holder #(.TAKE_IF(1'b1)) take_if();
  bind_duplicate_same_holder #(.TAKE_IF(1'b0)) take_else();
  bind_duplicate_leaf #(.TARGET_TAG(20)) children[3:1]();

  initial begin
    #1;
    if (bind_duplicate_counts::hit_if == 1
        && bind_duplicate_counts::hit_else == 1
        && bind_duplicate_counts::hit_array == 3
        && bind_duplicate_counts::errors == 0)
      $display("PASSED");
    else
      $display("FAILED: counts %0d %0d %0d errors %0d",
               bind_duplicate_counts::hit_if,
               bind_duplicate_counts::hit_else,
               bind_duplicate_counts::hit_array,
               bind_duplicate_counts::errors);
  end
endmodule

bind sv_bind_conditional_duplicate_targets.take_if.selected.child
  bind_duplicate_probe #(.ID(1), .EXPECT(11)) if_probe(
    .observed(TARGET_TAG)
  );

bind sv_bind_conditional_duplicate_targets.take_else.selected.child
  bind_duplicate_probe #(.ID(2), .EXPECT(12)) else_probe(
    .observed(TARGET_TAG)
  );

bind bind_duplicate_leaf :
  sv_bind_conditional_duplicate_targets.children[3],
  sv_bind_conditional_duplicate_targets.children[2],
  sv_bind_conditional_duplicate_targets.children[1]
  bind_duplicate_probe #(.ID(3), .EXPECT(20)) array_probe(
    .observed(TARGET_TAG)
  );
