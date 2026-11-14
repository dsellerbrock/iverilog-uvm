// IEEE 1800-2023 33.4.1.2: the use clause cannot be used with a default
// selection clause.
config cfg;
   design top;
   default use work.leaf;
endconfig

module top;
   leaf u();
endmodule

module leaf;
endmodule
