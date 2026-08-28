// IEEE 1800-2017/2023 7.6, 7.7 and 13.5: a one-dimensional fixed
// unpacked-array member is a legal actual for a native dynamic-array formal.
// The formal is normalized to 0..N-1; values and copyback map left-to-right.
interface payload_if;
  typedef struct {
    int asc[3:5];
    int desc[5:3];
    int md[1:2][7:5];
    byte bytes[-1:1];
    shortint shorts[9:7];
    real reals[2:3];
  } payload_if_t;
  payload_if_t data;
endinterface

module main;

  typedef struct {
    int asc[3:5];
    int desc[5:3];
    int md[1:2][7:5];
    byte bytes[-1:1];
    shortint shorts[9:7];
    real reals[2:3];
  } payload_t;

  class Holder;
    payload_t data;
  endclass

  payload_t direct;
  payload_t queued_payload;
  payload_t payloads[$];
  Holder holder;
  Holder queued_holder;
  Holder holders[$];
  payload_if pif();
  virtual payload_if vif;
  int dynamic_copy[];
  int empty_dynamic[];
  int empty_queue[$];
  int empty_hits;
  int payload_idx;
  int fails;

  task check(string what, bit good);
    if (!good) begin
      fails++;
      $display("FAILED -- %s", what);
    end
  endtask

  function automatic int sum_int(input int a[]);
    int sum;
    foreach (a[i]) sum += a[i];
    return sum;
  endfunction

  function automatic int sum_byte(input byte a[]);
    int sum;
    foreach (a[i]) sum += a[i];
    return sum;
  endfunction

  function automatic int sum_short(input shortint a[]);
    int sum;
    foreach (a[i]) sum += a[i];
    return sum;
  endfunction

  function automatic real sum_real(input real a[]);
    real sum;
    foreach (a[i]) sum += a[i];
    return sum;
  endfunction

  function automatic bit geometry_1d(input int a[]);
    return $size(a) == 3
        && $left(a) == 0 && $right(a) == 2
        && $low(a) == 0 && $high(a) == 2
        && $increment(a) == -1;
  endfunction

  function automatic bit descending_fill_order(input int a[]);
    return a[0] == 70 && a[1] == 71 && a[2] == 72;
  endfunction

  function automatic bit descending_input_order(input int a[]);
    return a[0] == 205 && a[1] == 204 && a[2] == 203;
  endfunction

  task automatic bump(input int delta, inout int a[]);
    foreach (a[i]) a[i] += delta;
  endtask

  task automatic fill(output int a[]);
    // An automatic output formal starts at its type default; it does not
    // borrow the fixed actual's shape or values (13.3.2). Allocate the
    // dynamic formal explicitly before the ordinary positional copy-out.
    if (a.size() != 0) begin
      fails++;
      $display("FAILED -- output formal copied in an actual shape");
    end
    a = new[3];
    foreach (a[i]) a[i] = 70 + i;
  endtask

  task automatic bump_real(input real delta, inout real a[]);
    foreach (a[i]) a[i] += delta;
  endtask

  initial begin
    holder = new;
    queued_holder = new;
    holders.push_back(queued_holder);
    foreach (empty_dynamic[i]) empty_hits++;
    foreach (empty_queue[i]) empty_hits++;
    check("empty runtime foreach stays empty", empty_hits == 0);

    foreach (direct.asc[i]) direct.asc[i] = 100 + i;
    foreach (direct.desc[i]) direct.desc[i] = 200 + i;
    foreach (direct.md[i,j]) direct.md[i][j] = 100*i + j;
    foreach (direct.bytes[i]) direct.bytes[i] = byte'(10 + i);
    foreach (direct.shorts[i]) direct.shorts[i] = shortint'(20 + i);
    foreach (direct.reals[i]) direct.reals[i] = 0.5 + i;
    holder.data = direct;
    holders[0].data = direct;
    queued_payload = direct;
    payloads.push_back(queued_payload);
    payload_idx = 0;
    foreach (pif.data.asc[i]) pif.data.asc[i] = direct.asc[i];
    foreach (pif.data.desc[i]) pif.data.desc[i] = direct.desc[i];
    vif = pif;
    dynamic_copy = direct.asc;

    check("ascending input and geometry",
          sum_int(direct.asc) == 312 && geometry_1d(direct.asc));
    check("descending input and geometry",
          sum_int(direct.desc) == 612 && geometry_1d(direct.desc)
          && descending_input_order(direct.desc));
    check("byte/shortint/real element types",
          sum_byte(direct.bytes) == 30
          && sum_short(direct.shorts) == 84
          && sum_real(direct.reals) == 6.0);
    check("class and container receiver input",
          sum_int(holder.data.asc) == 312
          && sum_int(holders[0].data.desc) == 612);
    check("struct stored directly in a runtime container",
          sum_int(payloads[payload_idx].asc) == 312);
    check("direct and virtual interface receiver input",
          sum_int(pif.data.asc) == 312
          && sum_int(vif.data.desc) == 612);
    check("ordinary fixed member to dynamic stays zero based",
          dynamic_copy.size() == 3 && $left(dynamic_copy) == 0
          && $right(dynamic_copy) == 2
          && dynamic_copy[0] == 103 && dynamic_copy[2] == 105);

    bump(10, direct.asc);
    fill(direct.desc);
    check("direct inout copyback",
          direct.asc[3] == 113 && direct.asc[5] == 115);
    check("direct output copyback",
          direct.desc[5] == 70 && direct.desc[3] == 72);

    bump(10, holder.data.asc);
    fill(holders[0].data.desc);
    check("class/container copyback",
          sum_int(holder.data.asc) == 342
          && sum_int(holders[0].data.desc) == 213);
    check("class descending copyback order",
          descending_fill_order(holders[0].data.desc)
          && queued_holder.data.desc[5] == 70
          && queued_holder.data.desc[4] == 71
          && queued_holder.data.desc[3] == 72);

    bump(5, payloads[payload_idx].asc);
    check("runtime-container struct copyback",
          sum_int(payloads[payload_idx].asc) == 327);

    bump(2, pif.data.asc);
    fill(vif.data.desc);
    check("direct/virtual interface copyback",
          sum_int(pif.data.asc) == 318
          && sum_int(pif.data.desc) == 213);
    check("virtual-interface descending copyback order",
          descending_fill_order(pif.data.desc)
          && pif.data.desc[5] == 70
          && pif.data.desc[4] == 71
          && pif.data.desc[3] == 72);

    bump_real(1.0, direct.reals);
    check("real-element inout copyback",
          direct.reals[2] == 3.5 && direct.reals[3] == 4.5);

    if (fails == 0) $display("PASSED");
    $finish(0);
  end
endmodule
