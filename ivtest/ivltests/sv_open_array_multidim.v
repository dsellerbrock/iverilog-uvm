// IEEE 1800-2017/2023 7.6, 7.7 and 13.5: a native `int q[][]`
// subroutine formal is a dynamic array of dynamic arrays. The outermost
// array kind may differ, so a queue of dynamic arrays is compatible; an
// inner fixed array or queue is part of the element type and is not.
//
// Fixed `int a[2][3]` -> `int q[][]` used to be accepted here as though all
// unpacked dimensions were open. That is a DPI rule, not native subroutine
// typing. The illegal spelling is now pinned by
// sv_subroutine_nested_container_formal_fail. This positive test keeps only
// equivalent nested element types and checks native normalized indexing,
// value copy-in, output initialization/allocation, and copyback.
module main;
  int nested[][];
  int queue_of_dynamic[$][];
  int fails;

  task automatic check(string what, bit good);
    if (!good) begin
      fails++;
      $display("FAILED -- %s", what);
    end
  endtask

  function automatic int sum2(input int value[][]);
    int total;
    foreach (value[i,j]) total += value[i][j];
    return total;
  endfunction

  function automatic bit normalized_geometry(input int value[][]);
    return $unpacked_dimensions(value) == 2
        && $size(value, 1) == 2
        && $left(value, 1) == 0 && $right(value, 1) == 1
        && $size(value, 2) == 3
        && $left(value, 2) == 0 && $right(value, 2) == 2;
  endfunction

  task automatic bump2(input int delta, inout int value[][]);
    foreach (value[i,j]) value[i][j] = value[i][j] + delta;
  endtask

  task automatic build2(output int value[][]);
    check("automatic output nested darray starts empty", value.size() == 0);
    value = new[2];
    foreach (value[i]) value[i] = new[3];
    foreach (value[i,j]) value[i][j] = 20 + 10*i + j;
  endtask

  initial begin
    nested = new[2];
    foreach (nested[i]) nested[i] = new[3];
    foreach (nested[i,j]) nested[i][j] = i*3 + j;
    queue_of_dynamic = '{'{0, 1, 2}, '{3, 4, 5}};

    check("nested dynamic input values", sum2(nested) == 15);
    check("nested dynamic normalized geometry", normalized_geometry(nested));
    check("queue-of-dynamic input values", sum2(queue_of_dynamic) == 15);
    check("queue-of-dynamic formal geometry",
          normalized_geometry(queue_of_dynamic));

    bump2(100, nested);
    check("nested dynamic inout copyback",
          nested[0][0] == 100 && nested[1][2] == 105);
    bump2(200, queue_of_dynamic);
    check("queue-of-dynamic inout copyback",
          queue_of_dynamic[0][0] == 200
          && queue_of_dynamic[1][2] == 205);

    build2(nested);
    check("nested dynamic output copyback",
          nested.size() == 2 && nested[0].size() == 3
          && nested[0][0] == 20 && nested[1][2] == 32);
    build2(queue_of_dynamic);
    check("queue-of-dynamic output copyback",
          queue_of_dynamic.size() == 2
          && queue_of_dynamic[0].size() == 3
          && queue_of_dynamic[0][0] == 20
          && queue_of_dynamic[1][2] == 32);

    if (fails == 0) $display("PASSED");
    else $display("FAILED (%0d)", fails);
    $finish(0);
  end
endmodule
