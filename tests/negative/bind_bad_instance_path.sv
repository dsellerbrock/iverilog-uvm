// M13B negative: a bind whose target instance path names an instance
// that does not exist must be rejected loudly (a typo must not make
// the bind a silent no-op).
module bind_checker(input logic c);
endmodule

module bind_leaf;
  logic data;
endmodule

module bind_bad_instance_path;
  bind_leaf u1();
endmodule

bind bind_bad_instance_path.u9 bind_checker c1(.c(data));
