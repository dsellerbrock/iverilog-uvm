class C;
  int st[4];

  function int rd(const ref int value);
    st[2] = 7;
    return value;
  endfunction
endclass

module issue2406_const_ref_class_property_array;
  C handle;

  initial begin
    handle = new;
    if (handle.rd(handle.st[2]) != 7)
      $fatal(1, "const ref class-property array element was copied");
    $display("passed");
  end
endmodule
