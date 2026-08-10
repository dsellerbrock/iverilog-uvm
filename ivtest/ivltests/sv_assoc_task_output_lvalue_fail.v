// IEEE 1800-2017 13.5.2 requires an output actual to be an l-value.
module sv_assoc_task_output_lvalue_fail;
  typedef int assoc_t[string];

  task automatic fill(output assoc_t value);
    value = '{default:1};
  endtask

  initial fill('{default:9});
endmodule
