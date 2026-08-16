// Caliptra compatibility extension: IEEE 1800-2017 19.6 restricts a cross
// item to a coverpoint label or variable identifier, but Caliptra uses
// hierarchical member expressions here. Preserve each complete expression.
interface coverage_if;
  typedef struct packed {
    logic valid;
    logic clear;
  } status_t;

  status_t producer;
  status_t consumer;

  covergroup hierarchical_cg;
    valid_x_clear: cross producer.valid, consumer.clear;
  endgroup

  hierarchical_cg coverage = new;

  task automatic sample_pair(input logic valid, input logic clear);
    producer.valid = valid;
    consumer.clear = clear;
    coverage.sample();
  endtask
endinterface

module top;
  coverage_if cov();

  initial begin
    cov.sample_pair(0, 0);
    cov.sample_pair(0, 1);
    cov.sample_pair(1, 0);
    cov.sample_pair(1, 1);
    if (cov.coverage.get_inst_coverage() != 100.0)
      $fatal(1, "hierarchical cross did not cover all four tuples");
    $display("PASSED");
    $finish;
  end
endmodule
