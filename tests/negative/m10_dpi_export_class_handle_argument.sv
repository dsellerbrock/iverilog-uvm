// NEG-DIAG: argument 'item' has a type not supported for export
// NEG-DIAG-COUNT: 1
// IEEE 1800-2017/2023 35.5.6 gives the exclusive DPI formal types; class
// handles are not in it. Foreign opaque objects cross DPI as chandle instead.
module m10_dpi_export_class_handle_argument;
  class payload;
    int value;
  endclass

  function int read_value(input payload item);
    return item == null ? 0 : item.value;
  endfunction
  export "DPI-C" function read_value;
endmodule
