// A package array parameter has no signal net. Foreach in a class method
// must resolve its lexical declaration and visit the declared indices.
package foreach_param_pkg;
  parameter string NAMES[] = {"access", "status", "hash"};
  parameter int DESCENDING[2:0] = '{11, 22, 33};

  class coverage_model;
    int seen;
    int index_code;
    int value_sum;
    string order;

    function new();
      foreach (NAMES[i]) begin
        seen++;
        index_code = index_code * 10 + i;
        order = {order, NAMES[i], ":"};
      end
      foreach (DESCENDING[j]) begin
        value_sum += DESCENDING[j];
        index_code = index_code * 10 + j;
      end
    endfunction
  endclass
endpackage

module main;
  foreach_param_pkg::coverage_model model;
  int empty[];
  int empty_seen;
  int local_array[2];
  int local_sum;

  initial begin
    model = new();
    if (model.seen != 3 || model.index_code != 12210
        || model.value_sum != 66
        || model.order != "access:status:hash:")
      $fatal(1, "package foreach: seen=%0d indices=%0d sum=%0d order=%s",
             model.seen, model.index_code, model.value_sum, model.order);

    // Empty dynamic array is the supported vacuity boundary. An empty
    // unsized parameter array currently fails during declaration elaboration.
    empty = new[0];
    foreach (empty[k]) empty_seen++;
    if (empty_seen != 0) $fatal(1, "empty foreach iterated");

    local_array[0] = 4;
    local_array[1] = 5;
    foreach (local_array[k]) local_sum += local_array[k];
    if (local_sum != 9) $fatal(1, "neighboring signal foreach failed");
    $display("PASSED");
  end
endmodule
