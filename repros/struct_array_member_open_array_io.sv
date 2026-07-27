module top;
  typedef struct {
    int asc[3:5];
    int desc[5:3];
    int md[1:2][7:5];
    byte bytes[-1:1];
    shortint shorts[9:7];
    real reals[2:3];
  } payload_t;

  payload_t direct;
  int plain[3:5];
  int fails;

  class Holder;
    payload_t data;
  endclass

  Holder holder;
  Holder queued_holder;
  Holder holders[$];

  function automatic int sum_int(input int a[]);
    int sum;
    foreach (a[i]) sum += a[i];
    return sum;
  endfunction

  function automatic int sum_md(input int a[][]);
    int sum;
    foreach (a[i,j]) sum += a[i][j];
    return sum;
  endfunction

  function automatic int geometry_int(input int a[], input int left,
                                      input int right);
    geometry_int = $size(a) == 3
        && $left(a) == left && $right(a) == right
        && $low(a) == ((left < right) ? left : right)
        && $high(a) == ((left > right) ? left : right)
        && $increment(a) == ((left >= right) ? 1 : -1);
    if (!geometry_int)
      $display("geometry got size=%0d left=%0d right=%0d low=%0d high=%0d inc=%0d",
               $size(a), $left(a), $right(a), $low(a), $high(a),
               $increment(a));
  endfunction

  function automatic int geometry_md(input int a[][]);
    return $unpacked_dimensions(a) == 2
        && $size(a, 1) == 2 && $left(a, 1) == 1
        && $right(a, 1) == 2 && $increment(a, 1) == -1
        && $size(a, 2) == 3 && $left(a, 2) == 7
        && $right(a, 2) == 5 && $low(a, 2) == 5
        && $high(a, 2) == 7 && $increment(a, 2) == 1
        && a[$left(a, 1)][$left(a, 2)] == 107;
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

  task automatic bump_int(inout int a[]);
    foreach (a[i]) a[i] += 10;
  endtask

  task automatic fill_int(output int a[]);
    foreach (a[i]) a[i] = 70 + i;
  endtask

  initial begin
    holder = new;
    queued_holder = new;
    holders.push_back(queued_holder);
    foreach (plain[i]) plain[i] = 100 + i;
    foreach (direct.asc[i]) direct.asc[i] = 100 + i;
    foreach (direct.desc[i]) direct.desc[i] = 200 + i;
    foreach (direct.md[i,j]) direct.md[i][j] = 100*i + j;
    foreach (direct.bytes[i]) direct.bytes[i] = byte'(10 + i);
    foreach (direct.shorts[i]) direct.shorts[i] = shortint'(20 + i);
    foreach (direct.reals[i]) direct.reals[i] = 0.5 + i;
    holder.data = direct;
    holders[0].data = direct;

    if (sum_int(plain) != 312) begin
      $display("FAILED plain control");
      fails++;
    end
    if (sum_int(direct.asc) != 312) begin
      $display("FAILED ascending member input");
      fails++;
    end
    if (sum_int(direct.desc) != 612) begin
      $display("FAILED descending member input");
      fails++;
    end
    if (!geometry_int(direct.asc, 3, 5)
        || !geometry_int(direct.desc, 5, 3)) begin
      $display("FAILED member open-array geometry");
      fails++;
    end
    if (sum_md(direct.md) != 936 || !geometry_md(direct.md)) begin
      $display("FAILED multidimensional member input: %0d",
               sum_md(direct.md));
      fails++;
    end
    if (sum_byte(direct.bytes) != 30
        || sum_short(direct.shorts) != 84
        || sum_real(direct.reals) != 6.0) begin
      $display("FAILED member element types");
      fails++;
    end
    if (sum_int(holder.data.asc) != 312
        || sum_int(holders[0].data.desc) != 612) begin
      $display("FAILED class/container stored struct member input");
      fails++;
    end

    bump_int(direct.asc);
    if (direct.asc[3] != 113 || direct.asc[5] != 115) begin
      $display("FAILED member inout copyback: %0d %0d",
               direct.asc[3], direct.asc[5]);
      fails++;
    end

    fill_int(direct.desc);
    if (direct.desc[3] != 73 || direct.desc[5] != 75) begin
      $display("FAILED member output copyback: %0d %0d",
               direct.desc[3], direct.desc[5]);
      fails++;
    end

    bump_int(holder.data.asc);
    fill_int(holders[0].data.desc);
    if (sum_int(holder.data.asc) != 342
        || sum_int(holders[0].data.desc) != 222) begin
      $display("FAILED class/container stored struct copyback");
      fails++;
    end

    if (fails == 0)
      $display("PASSED");
    $finish;
  end
endmodule
