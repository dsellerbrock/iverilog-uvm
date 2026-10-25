from pathlib import Path

out = Path("tests/1800_audit/c20/q")
probes = [
    ("dims_Word", "typedef logic [16:1] Word;", "", "$dimensions(Word)", "1"),
    ("unp_V", "logic [7:0] V;", "", "$unpacked_dimensions(V)", "0"),
    ("unp_a", "int a[3][][5];", "", "$unpacked_dimensions(a)", "3"),
    ("Word_size", "typedef logic [16:1] Word;", "", "$size(Word)", "16"),
    ("Word_left", "typedef logic [16:1] Word;", "", "$left(Word)", "16"),
    ("Word_right", "typedef logic [16:1] Word;", "", "$right(Word)", "1"),
    ("Ram_size2", "typedef logic [16:1] Word; Word Ram[0:9];", "", "$size(Ram,2)", "16"),
    ("Ram_size", "typedef logic [16:1] Word; Word Ram[0:9];", "", "$size(Ram)", "10"),
    ("N_left", "integer N;", "", "$left(N)", "31"),
    ("N_right", "integer N;", "", "$right(N)", "0"),
    ("SI_left", "shortint SI;", "", "$left(SI)", "15"),
    ("BY_left", "byte BY;", "", "$left(BY)", "7"),
    ("BY_size", "byte BY;", "", "$size(BY)", "8"),
    ("int_left", "", "", "$left(int)", "31"),
    ("aa_left", "int aa[int];", "aa[5]=1; aa[2]=1; aa[9]=1;", "$left(aa)", "0"),
    ("aa_right", "int aa[int];", "aa[5]=1; aa[2]=1; aa[9]=1;", "$right(aa)", ">=9"),
    ("aa_low", "int aa[int];", "aa[5]=1; aa[2]=1; aa[9]=1;", "$low(aa)", "2"),
    ("aa_high", "int aa[int];", "aa[5]=1; aa[2]=1; aa[9]=1;", "$high(aa)", "9"),
    ("aa_incr", "int aa[int];", "aa[5]=1; aa[2]=1; aa[9]=1;", "$increment(aa)", "-1"),
    ("aa_size", "int aa[int];", "aa[5]=1; aa[2]=1; aa[9]=1;", "$size(aa)", "3"),
    ("aa_empty_low", "int aa[int];", "aa[1]=1; aa.delete();", "$low(aa)", "x"),
    ("aa_empty_high", "int aa[int];", "aa[1]=1; aa.delete();", "$high(aa)", "x"),
    ("aa_empty_size", "int aa[int];", "aa[1]=1; aa.delete();", "$size(aa)", "0"),
    ("a_s1", "int a[3][][5];", "", "$size(a,1)", "3"),
    ("a_s3", "int a[3][][5];", "", "$size(a,3)", "5"),
    ("a2_size", "int a[3][][5];", "a[2]=new[4];", "$size(a[2],1)", "4"),
    ("a1_size", "int a[3][][5];", "", "$size(a[1],1)", "0"),
    ("a_s2_ERR", "int a[3][][5];", "a[2]=new[4];", "$size(a,2)", "error"),
    ("DT_size_ERR", "typedef int DT[];", "", "$size(DT)", "error"),
]
assert len(probes) == 29
assert len({name for name, *_ in probes}) == len(probes)
for name, decls, setup, expr, expected in probes:
    source = f'module m; {decls}\ninitial begin {setup} $display("Q {name}=%0d exp {expected}", {expr}); end endmodule\n'
    (out / f"q_{name}.sv").write_text(source)
print(f"generated {len(probes)} isolated probes")
