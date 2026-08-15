module sv_nettype_resolved_runtime_boundary_fail;
  function automatic logic [7:0] resolve_logic_sum(
      input logic [7:0] drivers[]);
    resolve_logic_sum = drivers.size() << 4;
    foreach (drivers[i])
      resolve_logic_sum[3:0] += drivers[i][3:0];
  endfunction

  function automatic bit [3:0] resolve_bit_xor(input bit [3:0] drivers[]);
    resolve_bit_xor = '0;
    foreach (drivers[i])
      resolve_bit_xor ^= drivers[i];
  endfunction

  function automatic real resolve_real_sum(input real drivers[]);
    resolve_real_sum = 0.0;
    foreach (drivers[i])
      resolve_real_sum += drivers[i];
  endfunction

  nettype logic [7:0] resolved_logic with resolve_logic_sum;
  nettype bit [3:0] resolved_bit with resolve_bit_xor;
  nettype real resolved_real with resolve_real_sum;

  logic [7:0] logic_single_driver;
  logic [7:0] logic_left_driver;
  logic [7:0] logic_right_driver;
  bit [3:0] bit_left_driver;
  bit [3:0] bit_right_driver;
  real real_left_driver;
  real real_right_driver;

  resolved_logic logic_single;
  resolved_logic logic_multi;
  resolved_bit bit_multi;
  resolved_real real_multi;

  assign logic_single = logic_single_driver;
  assign logic_multi = logic_left_driver;
  assign logic_multi = logic_right_driver;
  assign bit_multi = bit_left_driver;
  assign bit_multi = bit_right_driver;
  assign real_multi = real_left_driver;
  assign real_multi = real_right_driver;

  initial begin
    logic_single_driver = 8'h01;
    logic_left_driver = 8'h02;
    logic_right_driver = 8'h03;
    bit_left_driver = 4'h5;
    bit_right_driver = 4'h3;
    real_left_driver = 1.25;
    real_right_driver = 2.5;
    #1;

    if (logic_single !== 8'h11)
      $fatal(1, "one-driver logic resolver mismatch: %h", logic_single);
    if (logic_multi !== 8'h25)
      $fatal(1, "two-driver logic resolver mismatch: %h", logic_multi);
    if (bit_multi !== 4'h6)
      $fatal(1, "two-driver bit resolver mismatch: %h", bit_multi);
    if (real_multi != 3.75)
      $fatal(1, "two-driver real resolver mismatch: %f", real_multi);

    logic_single_driver = 8'h04;
    logic_left_driver = 8'h07;
    bit_right_driver = 4'hc;
    real_left_driver = -0.5;
    #1;

    if (logic_single !== 8'h14)
      $fatal(1, "changed one-driver logic resolver mismatch: %h", logic_single);
    if (logic_multi !== 8'h2a)
      $fatal(1, "changed two-driver logic resolver mismatch: %h", logic_multi);
    if (bit_multi !== 4'h9)
      $fatal(1, "changed two-driver bit resolver mismatch: %h", bit_multi);
    if (real_multi != 2.0)
      $fatal(1, "changed two-driver real resolver mismatch: %f", real_multi);

    $display("PASSED");
  end
endmodule
