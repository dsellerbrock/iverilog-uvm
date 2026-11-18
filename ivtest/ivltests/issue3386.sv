interface issue3386_bus #(parameter int N = 5);
  int n = N;
  extern function int get(input int bias = 2);
  extern function int increment(ref int value, ref int alias_value);
  extern function void put(input int, output int old);
  extern function real scale(input real factor);
  modport provider(ref n, export get, increment, put, scale);
  modport client(import function int get(input int bias = 4));
endinterface

module issue3386_provider(issue3386_bus.provider a);
  function int a.get(input int bias = 99);
    get = a.n + bias;
  endfunction : get

  function automatic int a.increment(ref int value, ref int alias_value);
    value++;
    return alias_value;
  endfunction

  function automatic void a.put;
    input int next_value;
    output int old;
    old = a.n;
    a.n = next_value;
  endfunction

  function real a.scale(input real factor);
    return a.n * factor;
  endfunction
endmodule

module issue3386_client(issue3386_bus.client a);
  int observed;
  always_comb observed = a.get();
endmodule

module issue3386;
  issue3386_bus i();
  issue3386_bus #(11) j();
  issue3386_provider pi(i.provider), pj(j.provider);
  issue3386_client ci(i.client);
  int observed, value, result;
  always_comb observed = i.get(1);

  initial begin
    #1;
    if (i.get(.bias(1)) !== 6 || i.get() !== 7 || j.get(1) !== 12)
      $fatal(1, "Wrong provider result or prototype default");
    if (i.scale(0.5) != 2.5 || j.scale(0.5) != 5.5)
      $fatal(1, "Wrong real provider result");
    if (observed !== 6 || ci.observed !== 9)
      $fatal(1, "Wrong initial result: %0d %0d", observed, ci.observed);

    value = 3;
    result = i.increment(value, value);
    if (result !== 4 || value !== 4)
      $fatal(1, "Aliased ref arguments did not reach the provider");

    i.put(8, value);
    if (value !== 5 || i.n !== 8 || j.n !== 11)
      $fatal(1, "Wrong void provider side effect or output argument");
    #1;
    if (observed !== 9 || ci.observed !== 12)
      $fatal(1, "Wrong updated result: %0d %0d", observed, ci.observed);
    $display("PASSED");
  end
endmodule
