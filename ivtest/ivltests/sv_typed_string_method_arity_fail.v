// IEEE 1800-2017/2023 6.16.1-6.16.10: built-in string methods have
// fixed signatures. Missing and extra arguments are hard compile errors.
module sv_typed_string_method_arity_fail;
  localparam string PARAM_SOURCE = "1234";
  string source;
  string text;
  int number;
  real real_number;

  initial begin
    number = source.len(1);
    number = source.atoi(1);
    real_number = source.atoreal(1);
    number = source.atohex(1);
    number = source.atobin(1);
    number = source.atooct(1);
    text = source.toupper(1);
    text = source.tolower(1);
    text = source.substr(0);
    number = source.compare();
    number = source.icompare();
    number = source.getc();
    number = PARAM_SOURCE.len(1);
    number = PARAM_SOURCE.atoi(1);
    real_number = PARAM_SOURCE.atoreal(1);
    number = PARAM_SOURCE.atohex(1);
    number = PARAM_SOURCE.atobin(1);
    number = PARAM_SOURCE.atooct(1);
    text = PARAM_SOURCE.toupper(1);
    text = PARAM_SOURCE.tolower(1);
    text = PARAM_SOURCE.substr(0);
    number = PARAM_SOURCE.compare();
    number = PARAM_SOURCE.icompare();
    number = PARAM_SOURCE.getc();
    text = source.substr(.wrong(0), .j(1));
    number = source.compare(.wrong("x"));
    number = source.getc(.wrong(0));
  end
endmodule
