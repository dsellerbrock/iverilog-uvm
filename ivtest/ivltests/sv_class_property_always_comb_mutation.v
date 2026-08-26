// IEEE 1800-2017 9.2.2.2.2: always_comb has an implicit sensitivity to
// expressions read by the procedure. An in-place class-property mutation must
// therefore retrigger this process even though the class handle is unchanged.
class class_property_always_comb_state;
  bit [7:0] field;
endclass

module sv_class_property_always_comb_mutation;
  class_property_always_comb_state state = new;
  logic [7:0] observed;

  always_comb observed = state.field;

  initial begin
    #1;
    if (observed !== 8'h00) begin
      $fatal(1, "initial always_comb value was %h", observed);
    end

    state.field = 8'h5a;
    #1;
    if (observed !== 8'h5a) begin
      $fatal(1, "in-place property mutation did not retrigger always_comb");
    end

    $display("PASSED");
  end
endmodule
