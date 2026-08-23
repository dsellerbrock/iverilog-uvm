// A run-time new[] size must still shape a lone-default pattern. Exercise the
// scalar-stack and object-stack fill paths, including value-copy versus class
// handle semantics for object-backed elements.
class fill_token;
  int value;

  function new(input int value);
    this.value = value;
  endfunction
endclass

module main;
  typedef struct {
    int value;
  } fill_struct;

  int count;
  bit [3:0] bit_values[];
  real real_values[];
  string string_values[];
  fill_token handle_values[];
  fill_struct struct_values[];
  int seed_array[];
  int nested_values[][];
  bit failed;

  task automatic check(input string label, input logic condition);
    if (condition !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  initial begin
    fill_token token;
    fill_struct seed_struct;

    failed = 1'b0;
    count = 5;
    token = new(17);
    seed_struct = '{value:29};
    seed_array = new[1];
    seed_array[0] = 41;

    bit_values = new[count]('{default:4'b10xz});
    real_values = new[count]('{default:2.5});
    string_values = new[count]('{default:"ready"});
    handle_values = new[count]('{default:token});
    struct_values = new[count]('{default:seed_struct});
    nested_values = new[count]('{default:seed_array});

    // The constructor captured the old value; changing the source variable
    // cannot resize an already-created array.
    count = 2;
    check("runtime size retained", bit_values.size() == 5);
    check("all result sizes agree",
          real_values.size() == 5 && string_values.size() == 5 &&
          handle_values.size() == 5 && struct_values.size() == 5 &&
          nested_values.size() == 5);

    foreach (bit_values[index]) begin
      check("2-state default conversion", bit_values[index] == 4'b1000);
      check("real default fill", real_values[index] == 2.5);
      check("string default fill", string_values[index] == "ready");
      check("class handle default fill", handle_values[index] == token);
      check("struct default fill", struct_values[index].value == 29);
      check("nested array size", nested_values[index].size() == 1);
      check("nested array default fill", nested_values[index][0] == 41);
    end

    // Class elements retain handle identity, while structs and dynamic arrays
    // are independently copied values.
    handle_values[0].value = 23;
    check("class handle identity", handle_values[1].value == 23);
    struct_values[0].value = 31;
    check("struct value copy", struct_values[1].value == 29);
    nested_values[0][0] = 43;
    check("nested dynamic-array value copy", nested_values[1][0] == 41);

    if (!failed)
      $display("PASSED");
  end
endmodule
