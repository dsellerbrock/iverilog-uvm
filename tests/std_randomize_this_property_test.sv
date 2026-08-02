// IEEE 1800-2017 18.12: std::randomize may name variables that happen
// to be properties of the current object. This remains scope randomization:
// class constraints and pre/post_randomize hooks do not participate.
module std_randomize_this_property_test;
  class request;
    rand bit scalar;
    rand bit shadowed;
    rand bit [7:0] payload[];
    int pre_calls;
    int post_calls;

    constraint class_rule { scalar == 0; }

    function void pre_randomize();
      pre_calls++;
    endfunction

    function void post_randomize();
      post_calls++;
    endfunction

    function bit randomize_scope_properties();
      if (!std::randomize(scalar) with { scalar == 1; }) return 0;
      if (!std::randomize(payload) with { payload.size() == 4; }) return 0;
      return scalar == 1 && payload.size() == 4;
    endfunction

    function bit randomize_shadowing_local();
      bit shadowed = 0;
      if (!std::randomize(shadowed) with { shadowed == 1; }) return 0;
      return shadowed == 1 && this.shadowed == 0;
    endfunction
  endclass

  request req;
  initial begin
    req = new();
    if (!req.randomize_scope_properties() ||
        !req.randomize_shadowing_local() ||
        req.pre_calls != 0 || req.post_calls != 0) begin
      $display("STD RANDOMIZE THIS PROPERTY TEST: FAIL scalar=%0b shadowed=%0b size=%0d hooks=%0d/%0d",
               req.scalar, req.shadowed, req.payload.size(),
               req.pre_calls, req.post_calls);
      $finish(1);
    end
    $display("STD RANDOMIZE THIS PROPERTY TEST: PASS");
    $finish(0);
  end
endmodule
