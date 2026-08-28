typedef real m10_real_darray_t[];
typedef real m10_real_queue_t[$];

class m10_container_conversion_box;
  real queue_by_key[int][$];
endclass

// M10: DPI open arrays (35.5.6.1, Annex H.12) — one-dimensional
// dynamic arrays of atom types passed as svOpenArrayHandle. The C
// side queries geometry with svSize/svLow/svHigh and reads/writes
// elements through svGetArrElemPtr1 directly in simulation storage,
// so writes are visible without any copy-back step.
module m10_dpi_openarray_test;

  import "DPI-C" function int c_arr_sum(input int arr[]);
  import "DPI-C" function int c_arr_fill(output int arr[], input int base);
  import "DPI-C" function longint c_arr_sum64(input longint arr[]);
  import "DPI-C" function int c_arr_bytes(inout byte arr[]);
  import "DPI-C" function real c_arr_mean(input real arr[]);
  import "DPI-C" function int c_arr_geom(input shortint arr[]);

  int pass_count = 0;
  int fail_count = 0;

  task check(input string name, input bit ok);
    if (ok) pass_count++;
    else begin
      fail_count++;
      $display("FAIL: %s", name);
    end
  endtask

  int di[];
  longint dl[];
  byte db[];
  real dr[];
  real queue_real[$];
  real alternate_queue_real[$];
  real queue_to_dynamic_real[];
  real queue_to_assoc_dynamic_real[int][];
  real selected_property_to_dynamic_real[];
  real conditional_to_dynamic_real[];
  real function_to_dynamic_real[];
  real cast_to_dynamic_real[];
  m10_container_conversion_box conversion_box;
  shortint dh[];
  int r;
  longint l;
  real m;
  bit ok;
  bit choose_queue;

  function automatic m10_real_queue_t return_real_queue();
    return_real_queue = '{8.0, 10.0};
  endfunction

  task automatic check_dynamic_task_input(input real d[]);
    real task_mean;
    task_mean = c_arr_mean(d);
    check("selected_property_task_copyin_runtime_kind", task_mean == 3.0);
  endtask

  initial begin
    // Read access: sum of elements.
    di = new[5];
    foreach (di[i]) di[i] = (i + 1) * 10;
    r = c_arr_sum(di);
    check("sum_int", r == 150);

    // Empty array: svSize 0, no element access.
    di = new[0];
    r = c_arr_sum(di);
    check("sum_empty", r == 0);

    // Write access through the handle (output direction).
    di = new[4];
    r = c_arr_fill(di, 100);
    check("fill_ret", r == 4);
    ok = 1;
    foreach (di[i]) if (di[i] != 100 + i) ok = 0;
    check("fill_elems", ok);

    // 64-bit elements.
    dl = new[3];
    dl[0] = 64'h1_0000_0000;
    dl[1] = 64'h2_0000_0000;
    dl[2] = -64'd12;
    l = c_arr_sum64(dl);
    check("sum64", l == 64'h3_0000_0000 - 64'd12);

    // Byte elements, inout: C doubles each in place and returns count.
    db = new[3];
    db[0] = 10; db[1] = -20; db[2] = 40;
    r = c_arr_bytes(db);
    check("bytes_ret", r == 3);
    check("bytes_elems", db[0] == 20 && db[1] == -40 && db[2] == 80);

    // Real elements.
    dr = new[4];
    dr[0] = 1.0; dr[1] = 2.0; dr[2] = 3.0; dr[3] = 6.0;
    m = c_arr_mean(dr);
    check("real_mean", m == 3.0);

    // A whole queue-to-dynamic-array assignment must create the declared
    // dynamic-array runtime flavor. Generic size/index checks cannot expose a
    // leaked queue object, but real[] DPI requires atom-contiguous dynamic
    // storage and therefore pins the destination kind directly.
    queue_real.push_back(2.0);
    queue_real.push_back(4.0);
    queue_to_dynamic_real = queue_real;
    m = c_arr_mean(queue_to_dynamic_real);
    check("queue_to_dynamic_runtime_kind", m == 3.0);

    // The same destination-kind rule applies when the dynamic array is an
    // associative-array element. Its map store performs a value copy, but it
    // must receive dynamic-array storage rather than retain the source queue.
    queue_to_assoc_dynamic_real[4] = queue_real;
    m = c_arr_mean(queue_to_assoc_dynamic_real[4]);
    check("queue_to_assoc_dynamic_runtime_kind", m == 3.0);

    // Selected property values, synthesized task copy-in, conditionals, user
    // function returns, and assignment-compatible casts all cross the same
    // destination-typed boundary. Value/size checks alone cannot distinguish
    // a queue object leaked behind a dynamic-array declaration; DPI can.
    conversion_box = new;
    conversion_box.queue_by_key[7] = queue_real;
    selected_property_to_dynamic_real = conversion_box.queue_by_key[7];
    m = c_arr_mean(selected_property_to_dynamic_real);
    check("selected_property_to_dynamic_runtime_kind", m == 3.0);
    check_dynamic_task_input(conversion_box.queue_by_key[7]);

    alternate_queue_real.push_back(6.0);
    alternate_queue_real.push_back(8.0);
    choose_queue = 1'b1;
    conditional_to_dynamic_real = choose_queue
          ? queue_real : alternate_queue_real;
    m = c_arr_mean(conditional_to_dynamic_real);
    check("conditional_to_dynamic_runtime_kind", m == 3.0);

    function_to_dynamic_real = return_real_queue();
    m = c_arr_mean(function_to_dynamic_real);
    check("function_return_to_dynamic_runtime_kind", m == 9.0);

    cast_to_dynamic_real = m10_real_darray_t'(queue_real);
    m = c_arr_mean(cast_to_dynamic_real);
    check("explicit_cast_to_dynamic_runtime_kind", m == 3.0);

    // Geometry queries on shortint elements: C checks svLow/svHigh/
    // svDimensions/svSizeOfArray consistency and returns 1.
    dh = new[7];
    foreach (dh[i]) dh[i] = i;
    r = c_arr_geom(dh);
    check("geometry", r == 1);

    if (fail_count == 0)
      $display("M10 DPI OPENARRAY TEST: PASS (%0d/%0d)", pass_count, pass_count);
    else
      $display("M10 DPI OPENARRAY TEST: FAIL (%0d passed, %0d failed)",
               pass_count, fail_count);
    $finish(0);
  end
endmodule
