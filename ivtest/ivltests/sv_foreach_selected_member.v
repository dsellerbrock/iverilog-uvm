// IEEE 1800-2017/2023 12.7.3, 23.7 and Annex A.6.8.
// Both editions 26.3: the selector's only reference must pin its import.
package foreach_selected_pkg;
  int chosen = 1;
endpackage
module main;
  import foreach_selected_pkg::*;
  typedef struct { int values[2]; } fixed_row_t;
  typedef struct { int values[$]; } queue_row_t;
  fixed_row_t fixed_rows[2] = '{'{ '{11,12} }, '{ '{21,22} }};
  queue_row_t queue_rows[$] = '{'{ '{31} }, '{ '{41,42} }};
  int matrix[2][3];
  int i = 87, j = 91;
  int visits, total, errors;

  function automatic int selected_sum(input int pick);
    int sum = 0;
    foreach (queue_rows[pick].values[j])
      sum += queue_rows[pick].values[j];
    return sum;
  endfunction

  initial begin
    visits = 0; total = 0;
    foreach (fixed_rows[k])
      foreach (fixed_rows[k].values[j]) begin
        visits++; total += fixed_rows[k].values[j];
      end
    if (visits != 4 || total != 66) begin
      $display("fixed selected prefix: visits=%0d total=%0d", visits, total);
      errors++;
    end

    visits = 0; total = 0;
    foreach (queue_rows[k])
      foreach (queue_rows[k].values[j]) begin
        visits++; total += queue_rows[k].values[j];
      end
    if (visits != 3 || total != 114) begin
      $display("queue selected prefix: visits=%0d total=%0d", visits, total);
      errors++;
    end
    if (selected_sum(0) != 31 || selected_sum(1) != 83) begin
      $display("function selector: sums=%0d,%0d", selected_sum(0), selected_sum(1));
      errors++;
    end

    visits = 0;
    foreach (queue_rows[chosen].values[j]) visits++;
    if (visits != 2) begin
      $display("wildcard selector: visits=%0d", visits);
      errors++;
    end

    // Only the final list declares iterators and shadows caller variables.
    visits = 0; total = 0;
    foreach (matrix[i,j]) begin
      matrix[i][j] = 10*i+j;
      visits++; total += matrix[i][j];
    end
    if (visits != 6 || total != 36 || i != 87 || j != 91) begin
      $display("ordinary multi-index/shadow: visits=%0d total=%0d i=%0d j=%0d",
               visits, total, i, j);
      errors++;
    end
    visits = 0; total = 0;
    foreach (queue_rows[1].values[j]) begin
      visits++; total += queue_rows[1].values[j];
    end
    if (visits != 2 || total != 83 || j != 91) begin
      $display("terminal shadow: visits=%0d total=%0d j=%0d", visits, total, j);
      errors++;
    end
    if (errors) $fatal(1, "selected foreach failures=%0d", errors);
    $display("PASSED");
  end
endmodule
