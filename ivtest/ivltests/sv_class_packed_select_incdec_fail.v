module sv_class_packed_select_incdec_fail;
  class holder;
    const logic [7:0] readonly_value = 8'ha5;
  endclass
  holder object; logic result;
  initial begin object=new;
    result=object.readonly_value[0]++;
  end
endmodule
