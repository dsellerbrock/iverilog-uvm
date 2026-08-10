// A pure associative output cannot copy its map object into an ordinary queue.
module sv_assoc_output_nonassoc_fail;
  typedef int assoc_t[string];
  int actual[$];

  task automatic produce(output assoc_t value);
    value = '{default:1};
  endtask

  initial produce(actual);
endmodule
