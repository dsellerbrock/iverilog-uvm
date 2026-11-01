module issue801_assoc_struct_p;
  typedef enum { OFF, ON } switch_e;
  typedef struct { switch_e sw; string s; } pair_t;
  pair_t va[int];
  string rendered_p;
  string rendered_0p;
  string rendered_string;

  function automatic bit contains_text(input string text,
                                       input string part);
    for (int i = 0; i + part.len() <= text.len(); i++)
      if (text.substr(i, i + part.len() - 1) == part)
        return 1;
    return 0;
  endfunction

  initial begin
    va[10] = '{sw:OFF, s:"switch10"};
    va[20] = '{sw:ON, s:"switch20"};

    rendered_p = $sformatf("%p", va);
    rendered_0p = $sformatf("%0p", va);
    rendered_string = $sformatf("%p", va[10].s);

    if (rendered_p != "'{10:'{sw:OFF, s:\"switch10\"}, 20:'{sw:ON, s:\"switch20\"}}") begin
      $display("FAILED %%p: %s", rendered_p);
      $fatal(1);
    end
    if (contains_text(rendered_0p, "?") ||
        !contains_text(rendered_0p, "\"switch10\"") ||
        !contains_text(rendered_0p, "\"switch20\"")) begin
      $display("FAILED %%0p: %s", rendered_0p);
      $fatal(1);
    end
    if (rendered_string != "\"switch10\"") begin
      $display("FAILED scalar string %%p: %s", rendered_string);
      $fatal(1);
    end

    $display("p=%s", rendered_p);
    $display("0p=%s", rendered_0p);
    $display("ISSUE801_PASSED");
    $display("PASSED");
    $finish;
  end
endmodule
