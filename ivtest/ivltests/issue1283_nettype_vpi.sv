module top;
  nettype logic base_nt;
  nettype base_nt alias_nt;

  function automatic logic resolve(input logic drivers[]);
    resolve = drivers[0];
  endfunction

  nettype logic resolved_nt with resolve;
endmodule
