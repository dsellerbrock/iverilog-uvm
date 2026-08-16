// IEEE 1800-2017 13.4.4 permits only fork...join_none in a function.
// Named/nested scopes and class methods do not change that restriction.
module top;
  function automatic int bad_join(input int value);
    begin : nested_function_scope
      fork : blocking_function_work
        bad_join = value;
      join
    end
  endfunction

  class fork_class;
    function int bad_join_any(input int value);
      begin : nested_method_scope
        fork : partial_function_work
          bad_join_any = value;
        join_any
      end
    endfunction
  endclass

  fork_class obj;

  initial begin
    obj = new;
    $display("%0d %0d", bad_join(1), obj.bad_join_any(2));
  end
endmodule
