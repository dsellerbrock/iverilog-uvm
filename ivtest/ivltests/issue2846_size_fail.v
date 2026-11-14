module issue2846_size_fail;
  typedef byte queue_t[$];
  typedef byte array_t[];
  queue_t q;
  array_t a;
  function automatic integer count(input queue_t value);
    return value.size();
  endfunction
  initial begin
    q = queue_t'(20'habcde);
    a = array_t'(20'habcde);
    q = queue_t'(4'ha);
    $display("%0d", count(queue_t'(4'ha)));
  end
endmodule
