class enum_const_box;
 typedef enum logic [3:0] {E_ZERO=0,E_TEN=10} value_t;
 const value_t values[];
 function new;values=new[1];endfunction
endclass
module sv_class_enum_container_packed_select_fail;
 enum_const_box b=new;
 initial b.values[0][1]=1'b1;
endmodule
