class sv_queue_fixed_array_concat_bad_element_class;
endclass
module sv_queue_fixed_array_concat_bad_element;
  sv_queue_fixed_array_concat_bad_element_class objects[2];
  bit [7:0] q[$];
  initial q = {objects};
endmodule
