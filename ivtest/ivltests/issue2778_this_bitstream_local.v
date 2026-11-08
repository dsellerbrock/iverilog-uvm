class issue2778_class;
  local byte value;
  function new(); value = 8'h5a; endfunction
  function byte packed_value(); packed_value = byte'(this); endfunction
endclass

module issue2778_this_bitstream_local;
  issue2778_class source;
  byte destination;
  initial begin
    source = new;
    destination = source.packed_value();
    if (destination != 8'h5a) $fatal(1, "this cast=%h", destination);
    $display("PASS this class bit-stream source");
  end
endmodule
