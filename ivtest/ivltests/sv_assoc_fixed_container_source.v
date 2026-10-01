// IEEE 1800-2017/2023 7.6, 7.8: OpenTitan flash_ctrl enum-keyed fixed
// values accept equal-size container copies and reject unequal-size copies.
class cfg;
  bit [7:0] m[int][3:2];

  function void check();
    bit [7:0] d[];
    bit [7:0] q[$];
    d = new[2]; d[0] = 8'hA5; d[1] = 8'h5A;
    q.push_back(8'hC3); q.push_back(8'h3C);
    m[1] = d;
    m[2] = q;
    if (m[1][3] !== 8'hA5 || m[1][2] !== 8'h5A
        || m[2][3] !== 8'hC3 || m[2][2] !== 8'h3C)
      $fatal(1, "class equal-size positional copy");
    d = new[1]; d[0] = 8'h11;
    q.delete(); q.push_back(8'h22);
    m[1] = d;
    m[3] = q;
    if (m[1][3] !== 8'hA5 || m[1][2] !== 8'h5A || m.exists(3))
      $fatal(1, "class unequal-size copy changed a key");
  endfunction
endclass

module top;
  bit [7:0] m[int][3:2];
  bit [7:0] d[];
  bit [7:0] q[$];
  cfg c;
  initial begin
    d = new[2]; d[0] = 8'hA5; d[1] = 8'h5A;
    q.push_back(8'hC3); q.push_back(8'h3C);
    m[1] = d;
    m[2] = q;
    if (m[1][3] !== 8'hA5 || m[1][2] !== 8'h5A
        || m[2][3] !== 8'hC3 || m[2][2] !== 8'h3C)
      $fatal(1, "module equal-size positional copy");
    d = new[1]; d[0] = 8'h11;
    q.delete(); q.push_back(8'h22);
    m[1] = d;
    m[3] = q;
    if (m[1][3] !== 8'hA5 || m[1][2] !== 8'h5A || m.exists(3))
      $fatal(1, "module unequal-size copy changed a key");
    c = new;
    c.check();
    $display("PASSED");
  end
endmodule
