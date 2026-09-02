// IEEE 1800-2017/2023 6.22.1 and 25.7 negative control: the dynamic VIF
// correspondence for one parsed result declaration must not make distinct
// interface-local enum, unpacked-record, or class declarations match.
interface local_nominal_result_fail_if;
  typedef enum logic [1:0] { ENUM_A, ENUM_B } enum_result_t;
  typedef enum logic [1:0] { OTHER_ENUM_A, OTHER_ENUM_B } other_enum_t;

  typedef struct { int value; } record_result_t;
  typedef struct { int value; } other_record_t;

  class class_result_t; int value; endclass
  class other_class_t; int value; endclass

  function automatic enum_result_t enum_value();
    return ENUM_A;
  endfunction
  function automatic record_result_t record_value();
    record_result_t result;
    result.value = 1;
    return result;
  endfunction
  function automatic class_result_t class_value();
    return null;
  endfunction

  modport rejected(
      import function other_enum_t enum_value(),
      import function other_record_t record_value(),
      import function other_class_t class_value()
  );
endinterface

module sv_vif_local_nominal_function_result_fail;
  local_nominal_result_fail_if concrete();
endmodule
