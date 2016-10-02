module cfg_grammar_gen;

/// PEG grammar for libconfig
enum configGrammar = r"
# Comments and include directive are not part of this grammar.
# They must be handled before the input is given to the PEG parser

Config:
    Document    <   Setting*

    Setting     <   Name (':' / '=') Value (';' / ',')?

    Value       <-  Scalar / Array / List / Group
    Scalar      <-  Bool / Float / Integer / String    # Float MUST be before Integer
    Array       <   '[' ( Scalar (',' Scalar)* )? ']'
    List        <   '(' ( Value (',' Value)* )? ')'
    Group       <   '{' Setting* '}'

    Name        <~  [A-Za-z] ( [-A-Za-z0-9_] )*

    Bool        <~  [Tt] [Rr] [Uu] [Ee] / [Ff] [Aa] [Ll] [Ss] [Ee]

    Integer     <-  (Hex / Dec) ('LL' / 'L')?
    Hex         <~  :'0' :[Xx] hexDigit+
    Dec         <~  [-+]? digits

    Float       <~  ( [-+]? digit* ^'.' digit* ( [eE] [-+]? digits )? ) /
                    ( [-+]? digit+ (^'.' digit*)? [eE] [-+]? digits )

    String      <~  :doublequote (
                        backslash backslash /
                        backslash doublequote /
                        backslash ^'f' /
                        backslash ^'n' /
                        backslash ^'r' /
                        backslash ^'t' /
                        !doublequote !backslash .
                    )* :doublequote
";

int main(string[] args) {
    import pegged.grammar : asModule;
    import std.stdio : stdout, stderr;
    import std.format : format;

    if (args.length == 0) args = ["cfg_grammar_gen"];

    immutable usage = (
        "usage:\n" ~
        "    %1$s [Options]\n"  ~
        "    Options:\n" ~
        "        -h --help      print this help message\n" ~
        "        -m --module    grammar module qualified name [mandatory]\n" ~
        "        -o --output    grammar module filename without extension [mandatory]\n" ~
        "    Example:\n" ~
        "        %1$s -m config.grammar -o src/config/grammar\n")
        .format(args[0]);

    int reportError(string msg) {
        stderr.writeln(msg);
        stderr.writeln(usage);
        return 1;
    }

    string modulefile;
    string modulename;

    for (size_t i=0; i<args.length; ++i) {
        if (args[i] == "-h" || args[i] == "--help") {
            stdout.writeln(usage);
            return 0;
        }
        if (args[i] == "-m" || args[i] == "--module") {
            ++i;
            if (i == args.length) return reportError("missing argument(s)");
            modulename = args[i];
        }
        if (args[i] == "-o" || args[i] == "--output") {
            ++i;
            if (i == args.length) return reportError("missing argument(s)");
            modulefile = args[i];
        }
    }

    if (!modulefile || !modulename) return reportError("missing argument(s)");

    asModule(modulename, modulefile, configGrammar);

    return 0;
}
