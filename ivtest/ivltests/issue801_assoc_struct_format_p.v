// IEEE 1800-2017/2023 21.2.1.7: %p traverses associative-array values
// through unpacked structs and formats their enum and string members.
module issue801_assoc_struct_format_p;
  typedef enum {ON, OFF} switch_e;
  typedef struct {switch_e sw; string s;} pair_t;
  pair_t va[int] = '{10:'{OFF, "switch10"}, 20:'{ON, "switch20"}};
  string pretty, compact;

  initial begin
    pretty = $sformatf("%p", va);
    compact = $sformatf("%0p", va);
    if (pretty != "'{10:'{sw:OFF, s:\"switch10\"}, 20:'{sw:ON, s:\"switch20\"}}") begin
      $display("FAILED %%p: %s", pretty);
      $finish;
    end
    if (compact != "'{10:'{sw:OFF, s:\"switch10\"}, 20:'{sw:ON, s:\"switch20\"}}") begin
      $display("FAILED %%0p: %s", compact);
      $finish;
    end
    $display("PASSED");
  end
endmodule
