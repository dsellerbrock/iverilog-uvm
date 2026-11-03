// IEEE 1800-2017/2023 7.6 and 10.4.2: an unpacked function result used
// by an NBA is captured before the scheduled word updates. Array assignment
// maps source and destination elements in declared left-to-right order.
module sv_uarray_func_return_nb;
  typedef int row_t [2:0];
  typedef int grid_t [2:1][0:1];

  int calls = 0;
  int selector_calls = 0;

  function automatic row_t make_row(input int first);
    calls++;
    make_row[2] = first;
    make_row[1] = first + 1;
    make_row[0] = first + 2;
  endfunction

  function automatic grid_t make_grid();
    calls++;
    make_grid[2][0] = 11;
    make_grid[2][1] = 12;
    make_grid[1][0] = 21;
    make_grid[1][1] = 22;
  endfunction

  function automatic int pick_row();
    selector_calls++;
    pick_row = 0;
  endfunction

  int whole [0:2];
  int matrix [1:0][0:2];
  int grid [0:1][0:1];
  int bad_row;

  initial begin
    whole[0] = 0;
    whole[1] = 0;
    whole[2] = 0;
    matrix[0][0] = 40;
    matrix[0][1] = 41;
    matrix[0][2] = 42;
    matrix[1][0] = 50;
    matrix[1][1] = 51;
    matrix[1][2] = 52;
    grid[0][0] = 0;
    grid[0][1] = 0;
    grid[1][0] = 0;
    grid[1][1] = 0;

    // The source is descending and the destination is ascending. The first
    // declared source element maps to the first declared destination word.
    whole <= make_row(10);
    whole[0] <= 99;

    // A row slice is one selected aggregate destination. The later scalar
    // NBA to its first word must retain same-process scheduling order.
    matrix[1] <= make_row(20);
    matrix[1][0] <= 91;

    // The selector is evaluated once even though the destination spans words.
    matrix[pick_row()] <= make_row(30);

    // An invalid dynamic row must leave every selected word untouched.
    bad_row = 9;
    matrix[bad_row] <= make_row(40);

    // Multidimensional arrays may differ in their slowest-varying bounds;
    // corresponding nested elements still follow declared order.
    grid <= make_grid();

    #1;
    if (whole[0] !== 99 || whole[1] !== 11 || whole[2] !== 12)
      $fatal(1, "whole array NBA: %0d,%0d,%0d", whole[0], whole[1], whole[2]);
    if (matrix[1][0] !== 91 || matrix[1][1] !== 21 || matrix[1][2] !== 22)
      $fatal(1, "row NBA order: %0d,%0d,%0d",
             matrix[1][0], matrix[1][1], matrix[1][2]);
    if (matrix[0][0] !== 30 || matrix[0][1] !== 31 || matrix[0][2] !== 32)
      $fatal(1, "dynamic row NBA: %0d,%0d,%0d",
             matrix[0][0], matrix[0][1], matrix[0][2]);
    if (grid[0][0] !== 11 || grid[0][1] !== 12
	|| grid[1][0] !== 21 || grid[1][1] !== 22)
      $fatal(1, "multidimensional NBA: %0d,%0d;%0d,%0d",
	     grid[0][0], grid[0][1], grid[1][0], grid[1][1]);
    if (calls != 5 || selector_calls != 1)
      $fatal(1, "evaluation counts: function=%0d selector=%0d",
             calls, selector_calls);

    $display("PASSED");
    $finish(0);
  end
endmodule
