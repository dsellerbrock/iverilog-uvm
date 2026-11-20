// IEEE 1800-2017/2023 6.22.2 and 7.6 require equivalent element types.
typedef logic [7:0] row_t[4:2];
typedef bit [7:0] queue_t[$];

module top;
  row_t m[int];
  bit [7:0] d[];

  function automatic queue_t source();
    return '{41, 42, 43};
  endfunction

  initial begin
    d = new[3];
    m = '{default: d};
    m = '{7: source()};
  end
endmodule
