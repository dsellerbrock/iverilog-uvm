// IEEE 1800-2017/2023 A.2.1.3, A.2.6-A.2.8 and 26.3.
// Imports following local declarations must preserve lexical lookup without
// generating an executable statement. No declarations follow statements here.
package import_left;
  typedef int value_t;
  parameter int value = 17;
endpackage
package import_right;
  typedef int value_t;
  parameter int value = 29;
endpackage

class import_user;
  function int read_value();
    int unused;
    import import_right::*;
    value_t result;
    result = value;
    return result;
  endfunction
  task read_task(output int result);
    int unused;
    import import_left::value_t, import_left::value;
    value_t local_value;
    local_value = value;
    result = local_value;
  endtask
endclass

module sv_procedural_package_import;
  import_user obj;
  int result;

  function int leading_import();
    import import_left::*;
    value_t result;
    result = value;
    return result;
  endfunction
  function int following_import();
    int unused;
    (* l43_import = 1 *)
    import import_right::value_t, import_right::value;
    value_t result;
    result = value;
    return result;
  endfunction
  task read_task(output int result);
    int unused;
    import import_left::*;
    value_t local_value;
    local_value = value;
    result = local_value;
  endtask

  initial begin
    if (leading_import() != 17 || following_import() != 29)
      $fatal(1, "module function import lookup failed");
    read_task(result);
    if (result != 17) $fatal(1, "module task import lookup failed");
    obj = new;
    if (obj.read_value() != 29) $fatal(1, "method import lookup failed");
    obj.read_task(result);
    if (result != 17) $fatal(1, "class task import lookup failed");
    begin : left_scope
      int unused;
      import import_left::*;
      value_t local_value;
      local_value = value;
      if (local_value != 17) $fatal(1, "left scope lookup failed");
    end
    begin : right_scope
      int unused;
      import import_right::*;
      value_t local_value;
      local_value = value;
      if (local_value != 29) $fatal(1, "right scope lookup failed");
    end
    $display("PASSED");
  end
endmodule
