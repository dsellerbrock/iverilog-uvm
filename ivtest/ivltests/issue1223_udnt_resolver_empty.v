module issue1223_udnt_resolver_empty;
  int resolver_calls = 0;
  function automatic logic resolve_values(input logic drivers[]);
    resolver_calls++;
    resolve_values = drivers.size() ? drivers[0] : 1'bx;
  endfunction

  nettype logic resolved_logic with resolve_values;
  resolved_logic net_value;

  initial begin
    #1;
    if (resolver_calls == 0)
      $fatal(1, "time-zero resolver was never activated");
    if (net_value !== 1'bx)
      $fatal(1, "default unresolved net value %b", net_value);
    $display("PASS");
  end
endmodule
