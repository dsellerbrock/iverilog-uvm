// IEEE 1800-2017/2023 6.22.2, 7.6, 7.9.11, 10.9.1
typedef logic [7:0] octet_t;
typedef octet_t row_t[4:2];
typedef logic [0:7] bytes_t[];
typedef logic [15:8] queue_t[$];

class item;
  int value;
endclass
typedef item handles_t[4:2];

class cfg;
  row_t m[int];
  handles_t handles[int];

  function void replace(input bytes_t d, input queue_t q);
    this.m = '{7: q, default: q, 8: d};
  endfunction
endclass

module top;
  cfg c, other;
  int calls;

  function automatic bytes_t source(input int digit, input bit reject_inner);
    queue_t q;
    bytes_t d;
    calls = calls * 10 + digit;
    q.push_back(10 * digit);
    if (!reject_inner) begin
      q.push_back(10 * digit + 1);
      q.push_back(10 * digit + 2);
    end
    other.m = '{default: q};
    d = new[3];
    d[0] = 10 * digit + 3;
    d[1] = 10 * digit + 4;
    d[2] = 10 * digit + 5;
    return d;
  endfunction

  task automatic replace_checked(input queue_t middle, input bit reject_inner);
    c.m = '{9: source(1, 0), 10: middle, default: source(2, reject_inner)};
  endtask

  task automatic check_original;
    if (c.m.num() != 2 || !c.m.exists(7) || !c.m.exists(8)
        || c.m.exists(9) || c.m.exists(10) || c.m.exists(99)
        || {c.m[7][4], c.m[7][3], c.m[7][2]} !== 24'h314253
        || {c.m[8][4], c.m[8][3], c.m[8][2]} !== 24'hx1z234
        || {c.m[99][4], c.m[99][3], c.m[99][2]} !== 24'h314253)
      $fatal(1, "old keys, values or default changed");
  endtask

  task automatic check_local(input bytes_t d, input queue_t q);
    row_t m[int];
    m = '{7: d, default: q};
    m = '{default: d, 8: q, 9: '{7, 8, 9}};
    if (m.num() != 2 || m.exists(7) || !m.exists(8) || !m.exists(9)
        || m[8][4] !== 8'h31 || m[9][2] !== 9 || m[99][2] !== 8'h34)
      $fatal(1, "procedural signal replacement");
    void'(q.pop_back());
    m = '{default: q};
    if (m.num() != 2 || !m.exists(8) || !m.exists(9)
        || m[8][2] !== 8'h53 || m[9][4] !== 7 || m[99][4] !== 8'hx1)
      $fatal(1, "procedural signal rollback");
  endtask

  initial begin
    bytes_t d, empty;
    queue_t q, short_q;
    item first, replacement;
    item refs[];

    c = new;
    other = new;
    d = new[3];
    d[0] = 8'hx1; d[1] = 8'hz2; d[2] = 8'h34;
    q.push_back(8'h31); q.push_back(8'h42); q.push_back(8'h53);
    short_q.push_back(8'hff);

    c.m = '{88: '{1, 2, 3}};
    c.m = '{default: d};
    if (c.m.num() != 0 || c.m.exists(88)
        || {c.m[99][4], c.m[99][3], c.m[99][2]} !== 24'hx1z234)
      $fatal(1, "default-only class replacement");

    check_local(d, q);
    c.replace(d, q);
    d[0] = 0;
    q[0] = 0;
    check_original();

    replace_checked(short_q, 0);
    check_original();
    if (calls != 12 || other.m.num() != 0
        || {other.m[99][4], other.m[99][3], other.m[99][2]} !== 24'h141516)
      $fatal(1, "source evaluation order, count or inner commit");

    c.m = '{default: q, 9: empty};
    check_original();
    c.m = '{default: short_q};
    check_original();

    q[0] = 8'h31;
    replace_checked(q, 1);
    if (calls != 1212 || c.m.num() != 2 || c.m.exists(7) || c.m.exists(8)
        || !c.m.exists(9) || !c.m.exists(10)
        || {c.m[9][4], c.m[9][3], c.m[9][2]} !== 24'h0d0e0f
        || {c.m[10][4], c.m[10][3], c.m[10][2]} !== 24'h314253
        || {c.m[99][4], c.m[99][3], c.m[99][2]} !== 24'h171819
        || {other.m[99][4], other.m[99][3], other.m[99][2]} !== 24'h0a0b0c)
      $fatal(1, "inner failure affected the outer commit or changed its map");

    first = new;
    replacement = new;
    refs = new[3];
    refs[0] = first;
    c.handles = '{default: refs};
    if (c.handles.num() != 0 || c.handles[99][4] != first)
      $fatal(1, "fixed child class handle default");
    c.handles = '{7: refs, default: refs};
    refs[0] = replacement;
    first.value = 91;
    if (c.handles[7][4] != first || c.handles[99][4] != first
        || c.handles[7][4].value != 91 || c.handles[7][2] != null)
      $fatal(1, "fixed child array copy or class handle identity");

    $display("PASSED");
  end
endmodule
