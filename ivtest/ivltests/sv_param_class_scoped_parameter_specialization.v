package class_parameter_scope_pkg;
  typedef struct packed {
    logic [3:0] x;
    logic [3:0] y;
  } pair_t;

  class box #(int VALUE = 1);
    parameter int DERIVED = VALUE + 2;
    parameter logic [7:0] BYTE_VALUE = 8'h40 + VALUE;

    static function int current_derived();
      return box::DERIVED;
    endfunction
  endclass

  class aggregate_box #(
    parameter pair_t PAIR = '{4'h1, 4'h2}
  );
  endclass

  class packed_aggregate_box #(
    parameter pair_t [1:0] PAIRS = {8'h12, 8'h34},
    parameter pair_t [1:0][2:0] GRID = '0
  );
  endclass

  class packed_select_box #(
    parameter logic [1:0][3:0] MATRIX = 8'ha5,
    parameter logic [7:0] VECTOR = 8'ha5
  );
  endclass

  class nested_value;
    parameter int VALUE = 13;
  endclass

  class nested_scope;
    typedef nested_value inner;
  endclass

  class base_box #(int VALUE = 1);
    parameter int INHERITED = VALUE;
  endclass

  class derived_box #(int VALUE = 2) extends base_box#(VALUE);
  endclass

  typedef box default_box;
endpackage

module test;
  import class_parameter_scope_pkg::*;
  localparam int LOCAL_VALUE = 9;
  localparam pair_t OVERRIDE_PAIR = '{4'h3, 4'h4};
  var type(aggregate_box#(OVERRIDE_PAIR)::PAIR[0]) pair_bit;
  var type(packed_select_box#()::MATRIX[1]) matrix_row;
  var type(packed_select_box#()::MATRIX[1][2]) matrix_bit;
  var type(packed_select_box#()::VECTOR[5:2]) vector_part;
  var type(packed_aggregate_box#()::GRID[1]) grid_row;
  var type(packed_aggregate_box#()::GRID[1][2]) grid_element;

  if ($bits(matrix_row) != 4) begin : bad_matrix_row_type
    missing_matrix_row_type u();
  end
  if ($bits(matrix_bit) != 1) begin : bad_matrix_bit_type
    missing_matrix_bit_type u();
  end
  if ($bits(vector_part) != 4) begin : bad_vector_part_type
    missing_vector_part_type u();
  end
  if ($bits(grid_row) != 24) begin : bad_grid_row_type
    missing_grid_row_type u();
  end
  if ($bits(grid_element) != 8) begin : bad_grid_element_type
    missing_grid_element_type u();
  end

  initial begin
    if (box#()::DERIVED != 3)
      $fatal(1, "default specialization parameter mismatch");
    if (box#(5)::DERIVED != 7 || box#(.VALUE(5))::DERIVED != 7)
      $fatal(1, "positional/named specialization parameter mismatch");
    if (box#(5)::BYTE_VALUE[3:0] != 4'h5)
      $fatal(1, "specialized parameter select mismatch");
    if (default_box::DERIVED != box#()::DERIVED)
      $fatal(1, "typedef default specialization mismatch");
    if (class_parameter_scope_pkg::box#(5)::DERIVED != 7)
      $fatal(1, "package-qualified specialization mismatch");
    if (class_parameter_scope_pkg::box#(LOCAL_VALUE)::DERIVED
        != LOCAL_VALUE + 2)
      $fatal(1, "package-qualified caller-scope override mismatch");
    if (class_parameter_scope_pkg::nested_scope::inner::VALUE != 13)
      $fatal(1, "nested class scope parameter mismatch");
    if (box#()::current_derived() != 3
        || box#(5)::current_derived() != 7)
      $fatal(1, "current-specialization class scope mismatch");
    if (aggregate_box#(OVERRIDE_PAIR)::PAIR.x != 4'h3)
      $fatal(1, "specialized aggregate parameter member mismatch");
    if (packed_aggregate_box#()::PAIRS[1].x != 4'h1
        || packed_aggregate_box#()::PAIRS[0].y != 4'h4)
      $fatal(1, "indexed aggregate parameter member mismatch");
    if ($bits(pair_bit) != 1)
      $fatal(1, "specialized parameter type select mismatch");
    if ($bits(matrix_row) != 4 || $bits(matrix_bit) != 1
        || $bits(vector_part) != 4 || $bits(grid_row) != 24
        || $bits(grid_element) != 8)
      $fatal(1, "specialized parameter type slice mismatch");
    if (derived_box#(5)::INHERITED != 5)
      $fatal(1, "inherited specialized parameter mismatch");
    $display("PASSED");
  end
endmodule
