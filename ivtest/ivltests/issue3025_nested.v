class item3025;
  int value;
endclass
module issue3025_nested;
  item3025 objects[2][], a, b, c, saved;
  integer row, col, row_calls, col_calls;
  function integer pick_row(); row_calls=row_calls+1; return 0; endfunction
  function integer pick_col(); col_calls=col_calls+1; return 1; endfunction
  initial begin
    objects[0] = new[2]; objects[1] = new[2];
    a=new; b=new; c=new;
    a.value=11; b.value=22; c.value=33;
    objects[0][0]=a; objects[0][1]=b; objects[1][0]=c; objects[1][1]=a;
    row=0; col=1;
    if (objects[row][col].value != 22 || objects[1][0].value != 33)
      $fatal(1, "independent reads");
    row_calls=0; col_calls=0;
    if (objects[pick_row()][pick_col()].value != 22 ||
        row_calls != 1 || col_calls != 1) $fatal(1, "index evaluation");
    objects[row][col].value=47;
    if (b.value != 47 || objects[0][0].value != 11) $fatal(1, "write alias");
    objects[1][1].value=59;
    if (a.value != 59 || objects[0][0].value != 59) $fatal(1, "shared object");
    saved=objects[0][1];
    if (saved != b || saved.value != 47) $fatal(1, "handle storage");
    objects[0][1]=c;
    if (objects[0][1].value != 33 || b.value != 47) $fatal(1, "handle replacement");
    $display("PASS");
  end
endmodule
