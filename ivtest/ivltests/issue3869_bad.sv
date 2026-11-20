module issue3869_bad;
  typedef byte byte_array[];
  byte associative[int];
  int non_byte[$];

  function automatic byte_array returned_array();
    byte_array data;
    return data;
  endfunction

  initial begin
    $swrite(associative, "abc");
    $sformat(non_byte, "abc");
    $swrite(returned_array(), "abc");
  end
endmodule
