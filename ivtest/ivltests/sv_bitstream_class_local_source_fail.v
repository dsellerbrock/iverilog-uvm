// IEEE 1800-2017/2023 6.24.3 forbids class handles with local or
// protected members as bit-stream cast sources outside the class instance.
class bitstream_local_source_class;
  local byte value;
endclass

module sv_bitstream_class_local_source_fail;
  bitstream_local_source_class source;
  byte destination;
  initial destination = byte'(source);
endmodule
