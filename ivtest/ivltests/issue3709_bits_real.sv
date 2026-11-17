module main;
  typedef shortreal sr_t;
  real r;
  shortreal s;
  realtime rt;
  localparam integer R = $bits(real), S = $bits(shortreal), T = $bits(realtime);
  localparam integer VR = $bits(r), VS = $bits(s), VT = $bits(rt);
  integer calls = 0;
  function real value();
    calls = calls + 1;
    return 1.0;
  endfunction
  function shortreal short_value();
    calls = calls + 1;
    return 1.0;
  endfunction
  initial begin
    if (R != 64 || S != 32 || T != 64 || $bits(sr_t) != 32 ||
        VR != 64 || VS != 32 || VT != 64 ||
        $bits(r) != 64 || $bits(s) != 32 || $bits(rt) != 64 ||
        $bits(shortreal'(r)) != 32 || $bits(real'(s)) != 64 ||
        $bits(r + s) != 64 || $bits(value()) != 64 ||
        $bits(short_value()) != 32 || calls != 0)
      $fatal(1, "incorrect real $bits result or expression evaluated");
    $display("PASS");
  end
endmodule
