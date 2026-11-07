// IEEE 1800-2017/2023 23.5: "An extern module declaration shall match the
// actual module declaration's port and parameter lists in correspondence
// of names, positions, and their equivalent types."
extern module p_order (input wire a, input wire b);
module p_order (input wire b, input wire a);
endmodule

extern module p_param #(parameter W = 1) (input wire a);
module p_param #(parameter N = 1) (input wire a);
endmodule

module no_ext (.*);
endmodule

extern interface not_a_module (input wire a);
