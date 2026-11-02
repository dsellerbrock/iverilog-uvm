// IEEE 1800-2017/2023 6.24.3: associative-array elements form a bit stream
// in sorted index order and can be converted to a queue.
module sv_assoc_cast_to_queue_fail;
  typedef int assoc_t[string];
  typedef int queue_t[$];
  assoc_t source;
  queue_t result;

  initial begin
    source["c"] = 3;
    source["a"] = 1;
    source["b"] = 2;
    result = queue_t'(source);
    if (result.size() != 3 || result[0] != 1
	|| result[1] != 2 || result[2] != 3)
	$fatal(1, "associative string-key bit-stream order");
    $display("%p", result);
  end
endmodule
