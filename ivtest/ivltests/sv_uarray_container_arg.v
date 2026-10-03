// IEEE 1800-2017/2023 13.5, 7.6, 7.8: a fixed unpacked array whose elements are
// queues or associative arrays passed as a subroutine argument, by value and by
// ref, including a class property as the actual (OpenTitan flash_ctrl passes
// `ref err_addr_tbl_t' = fixed array of associative arrays of associative arrays).
// The code generator refused every one of these ("cannot be used as an object").
module main;
  typedef int q_t[$];
  typedef bit aa_t[int];
  typedef bit [31:0] addr_t;
  typedef enum { PA, PB } part_e;
  typedef bit nested_t[addr_t][part_e];
  typedef nested_t tbl_t[2];

  q_t qa[2];
  aa_t aa[2];
  int errors;

  function automatic int qsum(q_t a[2]);
    return a[0].size() + 10 * a[1].size();
  endfunction
  function automatic int qsum_ref(ref q_t a[2]);
    return a[0].size() + 10 * a[1].size();
  endfunction
  function automatic int aanum(aa_t a[2]);
    return a[0].num() + 10 * a[1].num();
  endfunction
  // By-value formals are copies: mutating one must not touch the caller.
  function automatic int mutate_value(q_t a[2]);
    a[0].push_back(99);
    return a[0].size();
  endfunction
  // A ref formal denotes the caller's array: the push is visible afterwards.
  function automatic void mutate_ref(ref q_t a[2]);
    a[0].push_back(77);
  endfunction

  class cfg;
    tbl_t derr;
    local function bit has(ref tbl_t tb, input addr_t a, input part_e p);
      return (tb[0].exists(a) && tb[0][a].exists(p)) ||
             (tb[1].exists(a) && tb[1][a].exists(p));
    endfunction
    function void note(int row, addr_t a, part_e p); derr[row][a][p] = 1; endfunction
    function bit has_derr(addr_t a, part_e p); return has(derr, a, p); endfunction
  endclass

  initial begin
    cfg c;
    qa[0].push_back(1); qa[1].push_back(2); qa[1].push_back(3);
    if (qsum(qa) !== 21) begin $display("FAILED qsum by value %0d", qsum(qa)); errors++; end
    if (qsum_ref(qa) !== 21) begin $display("FAILED qsum by ref"); errors++; end

    aa[0][5] = 1; aa[1][6] = 1; aa[1][7] = 1;
    if (aanum(aa) !== 21) begin $display("FAILED aanum"); errors++; end

    if (mutate_value(qa) !== 2) begin $display("FAILED by-value push result"); errors++; end
    if (qa[0].size() !== 1) begin
      $display("FAILED by-value formal aliased the caller (%0d)", qa[0].size()); errors++;
    end
    mutate_ref(qa);
    if (qa[0].size() !== 2 || qa[0][1] !== 77) begin
      $display("FAILED ref formal did not write through (%0d)", qa[0].size()); errors++;
    end

    c = new;
    c.note(1, 32'h10, PB);
    if (c.has_derr(32'h10, PB) !== 1'b1) begin $display("FAILED has hit"); errors++; end
    if (c.has_derr(32'h10, PA) !== 1'b0) begin $display("FAILED has wrong part"); errors++; end
    if (c.has_derr(32'h11, PB) !== 1'b0) begin $display("FAILED has wrong addr"); errors++; end
    if (errors == 0) $display("PASSED");
  end
endmodule
