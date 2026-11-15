// IEEE 1800-2023 33.4.1.4: it is an error if a cell clause names a library
// and its expansion clause is a library list.
config cfg;
   design top;
   cell work.leaf liblist work;
endconfig

module top;
   leaf u();
endmodule

module leaf;
endmodule
