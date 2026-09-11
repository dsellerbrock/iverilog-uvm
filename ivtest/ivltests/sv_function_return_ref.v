// IEEE 1800-2017/2023 13.4.1, 13.5.2: addressable function-name storage.
module sv_function_return_ref;
  class Reader;
    static function bit fill(ref int value);
      value = 23;
      return 1;
    endfunction
  endclass
  class Coverage;
    function int value();
      value = 0;
      if (!Reader::fill(value)) $fatal(1,"static method ref call");
      value &= 31;
    endfunction
  endclass
  int seen_a, seen_b;
  function automatic int aliases(ref int a, ref int b);
    a = 9;
    if (b != 9) $fatal(1,"ref aliases diverged");
    b += 3;
    return a;
  endfunction
  function automatic int recurse(input int depth);
    int inner;
    recurse = 7;
    inner = aliases(recurse,recurse);
    if (recurse != 12 || inner != 12) $fatal(1,"synchronous alias");
    if (depth != 0) begin
      inner = recurse(depth-1);
      if (recurse != 12) $fatal(1,"recursive frame clobbered");
      recurse += inner;
    end
  endfunction
  function automatic void bump(ref int value);
    value += 5;
  endfunction
  function automatic int explicit_result();
    explicit_result = 7;
    bump(explicit_result);
    begin : nested
      return explicit_result + 5;
    end
    explicit_result = 999;
  endfunction
  function int persistent();
    persistent += 1;
    bump(persistent);
  endfunction
  function automatic void set_four(ref logic [3:0] value);
    value = 4'bxz01;
  endfunction
  function automatic logic [3:0] four_state();
    set_four(four_state);
    four_state[0] = 0;
  endfunction
  task automatic late_write(ref int value,input int tag);
    #1;
    value += 5;
    if(tag==0) seen_a=value; else seen_b=value;
  endtask
  function automatic int detached(input int value,input int tag);
    detached=value;
    fork
      late_write(detached,tag);
    join_none
  endfunction
  initial begin
    int a,b;
    Coverage coverage;
    coverage = new;
    if(coverage.value()!=23) $fatal(1,"method return ref");
    if(recurse(2)!=36) $fatal(1,"recursive result");
    if(explicit_result()!=17) $fatal(1,"explicit return");
    if(persistent()!=6 || persistent()!=12) $fatal(1,"static return storage");
    if(four_state()!==4'bxz00) $fatal(1,"four-state partial update");
    a=detached(7,0);
    b=detached(20,1);
    if(a!=7 || b!=20) $fatal(1,"return snapshot");
    #2;
    if(seen_a!=12 || seen_b!=25) $fatal(1,"detached return storage lifetime %0d %0d",seen_a,seen_b);
    $display("PASSED");
  end
endmodule
