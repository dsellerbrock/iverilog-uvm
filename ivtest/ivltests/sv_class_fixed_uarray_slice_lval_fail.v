module test;
  class holder_t;
    int values[0:3];

    function void reject(int base);
      values[2:1] = '{1, 2};
      values[2:4] = '{1, 2, 3};
      values[base +: 2] = '{1, 2};
      values[0:0] <= '{0};
    endfunction
endclass

typedef int fixed_row_t[0:1];

class nested_fixed_slice_holder_t;
  fixed_row_t rows[0:3];
endclass

module nested_fixed_slice_lval_fail;
  initial begin
    nested_fixed_slice_holder_t holder;
    holder = new;
    holder.rows[1] = '{11, 12};
    holder.rows[1:2] = '{'{21, 22}, '{31, 32}};
  end
endmodule
endmodule
