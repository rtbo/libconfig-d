/++
This module was automatically generated from the following grammar:


# Comments and include directive are not part of this grammar.
# They must be handled before the input is given to the PEG parser

Config:
    Document    <   eoi / Setting+

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

    StringQuot  <~  :doublequote (
                        backslash backslash /
                        backslash doublequote /
                        backslash ^'f' /
                        backslash ^'n' /
                        backslash ^'r' /
                        backslash ^'t' /
                        !doublequote !backslash .
                    )* :doublequote

    String      <~  (StringQuot spacing?)+


+/
module config.grammar;

public import pegged.peg;
import std.algorithm: startsWith;
import std.functional: toDelegate;

struct GenericConfig(TParseTree)
{
	import std.functional : toDelegate;
    import pegged.dynamic.grammar;
	static import pegged.peg;
    struct Config
    {
    enum name = "Config";
    static ParseTree delegate(ParseTree)[string] before;
    static ParseTree delegate(ParseTree)[string] after;
    static ParseTree delegate(ParseTree)[string] rules;
    import std.typecons:Tuple, tuple;
    static TParseTree[Tuple!(string, size_t)] memo;
    static this()
    {
        rules["Document"] = toDelegate(&Document);
        rules["Setting"] = toDelegate(&Setting);
        rules["Value"] = toDelegate(&Value);
        rules["Scalar"] = toDelegate(&Scalar);
        rules["Array"] = toDelegate(&Array);
        rules["List"] = toDelegate(&List);
        rules["Group"] = toDelegate(&Group);
        rules["Name"] = toDelegate(&Name);
        rules["Bool"] = toDelegate(&Bool);
        rules["Integer"] = toDelegate(&Integer);
        rules["Hex"] = toDelegate(&Hex);
        rules["Dec"] = toDelegate(&Dec);
        rules["Float"] = toDelegate(&Float);
        rules["StringQuot"] = toDelegate(&StringQuot);
        rules["String"] = toDelegate(&String);
        rules["Spacing"] = toDelegate(&Spacing);
    }

    template hooked(alias r, string name)
    {
        static ParseTree hooked(ParseTree p)
        {
            ParseTree result;

            if (name in before)
            {
                result = before[name](p);
                if (result.successful)
                    return result;
            }

            result = r(p);
            if (result.successful || name !in after)
                return result;

            result = after[name](p);
            return result;
        }

        static ParseTree hooked(string input)
        {
            return hooked!(r, name)(ParseTree("",false,[],input));
        }
    }

    static void addRuleBefore(string parentRule, string ruleSyntax)
    {
        // enum name is the current grammar name
        DynamicGrammar dg = pegged.dynamic.grammar.grammar(name ~ ": " ~ ruleSyntax, rules);
        foreach(ruleName,rule; dg.rules)
            if (ruleName != "Spacing") // Keep the local Spacing rule, do not overwrite it
                rules[ruleName] = rule;
        before[parentRule] = rules[dg.startingRule];
    }

    static void addRuleAfter(string parentRule, string ruleSyntax)
    {
        // enum name is the current grammar named
        DynamicGrammar dg = pegged.dynamic.grammar.grammar(name ~ ": " ~ ruleSyntax, rules);
        foreach(name,rule; dg.rules)
        {
            if (name != "Spacing")
                rules[name] = rule;
        }
        after[parentRule] = rules[dg.startingRule];
    }

    static bool isRule(string s)
    {
		import std.algorithm : startsWith;
        return s.startsWith("Config.");
    }
    mixin decimateTree;

    alias spacing Spacing;

    static TParseTree Document(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.wrapAround!(Spacing, eoi, Spacing), pegged.peg.oneOrMore!(pegged.peg.wrapAround!(Spacing, Setting, Spacing))), "Config.Document")(p);
        }
        else
        {
            if (auto m = tuple(`Document`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.wrapAround!(Spacing, eoi, Spacing), pegged.peg.oneOrMore!(pegged.peg.wrapAround!(Spacing, Setting, Spacing))), "Config.Document"), "Document")(p);
                memo[tuple(`Document`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Document(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.wrapAround!(Spacing, eoi, Spacing), pegged.peg.oneOrMore!(pegged.peg.wrapAround!(Spacing, Setting, Spacing))), "Config.Document")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.wrapAround!(Spacing, eoi, Spacing), pegged.peg.oneOrMore!(pegged.peg.wrapAround!(Spacing, Setting, Spacing))), "Config.Document"), "Document")(TParseTree("", false,[], s));
        }
    }
    static string Document(GetName g)
    {
        return "Config.Document";
    }

    static TParseTree Setting(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.wrapAround!(Spacing, Name, Spacing), pegged.peg.wrapAround!(Spacing, pegged.peg.or!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(":"), Spacing), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("="), Spacing)), Spacing), pegged.peg.wrapAround!(Spacing, Value, Spacing), pegged.peg.option!(pegged.peg.wrapAround!(Spacing, pegged.peg.or!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(";"), Spacing), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(","), Spacing)), Spacing))), "Config.Setting")(p);
        }
        else
        {
            if (auto m = tuple(`Setting`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.wrapAround!(Spacing, Name, Spacing), pegged.peg.wrapAround!(Spacing, pegged.peg.or!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(":"), Spacing), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("="), Spacing)), Spacing), pegged.peg.wrapAround!(Spacing, Value, Spacing), pegged.peg.option!(pegged.peg.wrapAround!(Spacing, pegged.peg.or!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(";"), Spacing), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(","), Spacing)), Spacing))), "Config.Setting"), "Setting")(p);
                memo[tuple(`Setting`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Setting(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.wrapAround!(Spacing, Name, Spacing), pegged.peg.wrapAround!(Spacing, pegged.peg.or!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(":"), Spacing), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("="), Spacing)), Spacing), pegged.peg.wrapAround!(Spacing, Value, Spacing), pegged.peg.option!(pegged.peg.wrapAround!(Spacing, pegged.peg.or!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(";"), Spacing), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(","), Spacing)), Spacing))), "Config.Setting")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.wrapAround!(Spacing, Name, Spacing), pegged.peg.wrapAround!(Spacing, pegged.peg.or!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(":"), Spacing), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("="), Spacing)), Spacing), pegged.peg.wrapAround!(Spacing, Value, Spacing), pegged.peg.option!(pegged.peg.wrapAround!(Spacing, pegged.peg.or!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(";"), Spacing), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(","), Spacing)), Spacing))), "Config.Setting"), "Setting")(TParseTree("", false,[], s));
        }
    }
    static string Setting(GetName g)
    {
        return "Config.Setting";
    }

    static TParseTree Value(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(Scalar, Array, List, Group), "Config.Value")(p);
        }
        else
        {
            if (auto m = tuple(`Value`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(Scalar, Array, List, Group), "Config.Value"), "Value")(p);
                memo[tuple(`Value`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Value(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(Scalar, Array, List, Group), "Config.Value")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(Scalar, Array, List, Group), "Config.Value"), "Value")(TParseTree("", false,[], s));
        }
    }
    static string Value(GetName g)
    {
        return "Config.Value";
    }

    static TParseTree Scalar(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(Bool, Float, Integer, String), "Config.Scalar")(p);
        }
        else
        {
            if (auto m = tuple(`Scalar`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(Bool, Float, Integer, String), "Config.Scalar"), "Scalar")(p);
                memo[tuple(`Scalar`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Scalar(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(Bool, Float, Integer, String), "Config.Scalar")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(Bool, Float, Integer, String), "Config.Scalar"), "Scalar")(TParseTree("", false,[], s));
        }
    }
    static string Scalar(GetName g)
    {
        return "Config.Scalar";
    }

    static TParseTree Array(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("["), Spacing), pegged.peg.option!(pegged.peg.wrapAround!(Spacing, pegged.peg.and!(pegged.peg.wrapAround!(Spacing, Scalar, Spacing), pegged.peg.zeroOrMore!(pegged.peg.wrapAround!(Spacing, pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(","), Spacing), pegged.peg.wrapAround!(Spacing, Scalar, Spacing)), Spacing))), Spacing)), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("]"), Spacing)), "Config.Array")(p);
        }
        else
        {
            if (auto m = tuple(`Array`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("["), Spacing), pegged.peg.option!(pegged.peg.wrapAround!(Spacing, pegged.peg.and!(pegged.peg.wrapAround!(Spacing, Scalar, Spacing), pegged.peg.zeroOrMore!(pegged.peg.wrapAround!(Spacing, pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(","), Spacing), pegged.peg.wrapAround!(Spacing, Scalar, Spacing)), Spacing))), Spacing)), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("]"), Spacing)), "Config.Array"), "Array")(p);
                memo[tuple(`Array`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Array(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("["), Spacing), pegged.peg.option!(pegged.peg.wrapAround!(Spacing, pegged.peg.and!(pegged.peg.wrapAround!(Spacing, Scalar, Spacing), pegged.peg.zeroOrMore!(pegged.peg.wrapAround!(Spacing, pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(","), Spacing), pegged.peg.wrapAround!(Spacing, Scalar, Spacing)), Spacing))), Spacing)), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("]"), Spacing)), "Config.Array")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("["), Spacing), pegged.peg.option!(pegged.peg.wrapAround!(Spacing, pegged.peg.and!(pegged.peg.wrapAround!(Spacing, Scalar, Spacing), pegged.peg.zeroOrMore!(pegged.peg.wrapAround!(Spacing, pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(","), Spacing), pegged.peg.wrapAround!(Spacing, Scalar, Spacing)), Spacing))), Spacing)), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("]"), Spacing)), "Config.Array"), "Array")(TParseTree("", false,[], s));
        }
    }
    static string Array(GetName g)
    {
        return "Config.Array";
    }

    static TParseTree List(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("("), Spacing), pegged.peg.option!(pegged.peg.wrapAround!(Spacing, pegged.peg.and!(pegged.peg.wrapAround!(Spacing, Value, Spacing), pegged.peg.zeroOrMore!(pegged.peg.wrapAround!(Spacing, pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(","), Spacing), pegged.peg.wrapAround!(Spacing, Value, Spacing)), Spacing))), Spacing)), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(")"), Spacing)), "Config.List")(p);
        }
        else
        {
            if (auto m = tuple(`List`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("("), Spacing), pegged.peg.option!(pegged.peg.wrapAround!(Spacing, pegged.peg.and!(pegged.peg.wrapAround!(Spacing, Value, Spacing), pegged.peg.zeroOrMore!(pegged.peg.wrapAround!(Spacing, pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(","), Spacing), pegged.peg.wrapAround!(Spacing, Value, Spacing)), Spacing))), Spacing)), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(")"), Spacing)), "Config.List"), "List")(p);
                memo[tuple(`List`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree List(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("("), Spacing), pegged.peg.option!(pegged.peg.wrapAround!(Spacing, pegged.peg.and!(pegged.peg.wrapAround!(Spacing, Value, Spacing), pegged.peg.zeroOrMore!(pegged.peg.wrapAround!(Spacing, pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(","), Spacing), pegged.peg.wrapAround!(Spacing, Value, Spacing)), Spacing))), Spacing)), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(")"), Spacing)), "Config.List")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("("), Spacing), pegged.peg.option!(pegged.peg.wrapAround!(Spacing, pegged.peg.and!(pegged.peg.wrapAround!(Spacing, Value, Spacing), pegged.peg.zeroOrMore!(pegged.peg.wrapAround!(Spacing, pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(","), Spacing), pegged.peg.wrapAround!(Spacing, Value, Spacing)), Spacing))), Spacing)), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!(")"), Spacing)), "Config.List"), "List")(TParseTree("", false,[], s));
        }
    }
    static string List(GetName g)
    {
        return "Config.List";
    }

    static TParseTree Group(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("{"), Spacing), pegged.peg.zeroOrMore!(pegged.peg.wrapAround!(Spacing, Setting, Spacing)), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("}"), Spacing)), "Config.Group")(p);
        }
        else
        {
            if (auto m = tuple(`Group`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("{"), Spacing), pegged.peg.zeroOrMore!(pegged.peg.wrapAround!(Spacing, Setting, Spacing)), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("}"), Spacing)), "Config.Group"), "Group")(p);
                memo[tuple(`Group`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Group(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("{"), Spacing), pegged.peg.zeroOrMore!(pegged.peg.wrapAround!(Spacing, Setting, Spacing)), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("}"), Spacing)), "Config.Group")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("{"), Spacing), pegged.peg.zeroOrMore!(pegged.peg.wrapAround!(Spacing, Setting, Spacing)), pegged.peg.wrapAround!(Spacing, pegged.peg.literal!("}"), Spacing)), "Config.Group"), "Group")(TParseTree("", false,[], s));
        }
    }
    static string Group(GetName g)
    {
        return "Config.Group";
    }

    static TParseTree Name(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.or!(pegged.peg.charRange!('A', 'Z'), pegged.peg.charRange!('a', 'z')), pegged.peg.zeroOrMore!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.charRange!('A', 'Z'), pegged.peg.charRange!('a', 'z'), pegged.peg.charRange!('0', '9'), pegged.peg.literal!("_"))))), "Config.Name")(p);
        }
        else
        {
            if (auto m = tuple(`Name`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.or!(pegged.peg.charRange!('A', 'Z'), pegged.peg.charRange!('a', 'z')), pegged.peg.zeroOrMore!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.charRange!('A', 'Z'), pegged.peg.charRange!('a', 'z'), pegged.peg.charRange!('0', '9'), pegged.peg.literal!("_"))))), "Config.Name"), "Name")(p);
                memo[tuple(`Name`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Name(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.or!(pegged.peg.charRange!('A', 'Z'), pegged.peg.charRange!('a', 'z')), pegged.peg.zeroOrMore!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.charRange!('A', 'Z'), pegged.peg.charRange!('a', 'z'), pegged.peg.charRange!('0', '9'), pegged.peg.literal!("_"))))), "Config.Name")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.or!(pegged.peg.charRange!('A', 'Z'), pegged.peg.charRange!('a', 'z')), pegged.peg.zeroOrMore!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.charRange!('A', 'Z'), pegged.peg.charRange!('a', 'z'), pegged.peg.charRange!('0', '9'), pegged.peg.literal!("_"))))), "Config.Name"), "Name")(TParseTree("", false,[], s));
        }
    }
    static string Name(GetName g)
    {
        return "Config.Name";
    }

    static TParseTree Bool(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.or!(pegged.peg.and!(pegged.peg.or!(pegged.peg.literal!("T"), pegged.peg.literal!("t")), pegged.peg.or!(pegged.peg.literal!("R"), pegged.peg.literal!("r")), pegged.peg.or!(pegged.peg.literal!("U"), pegged.peg.literal!("u")), pegged.peg.or!(pegged.peg.literal!("E"), pegged.peg.literal!("e"))), pegged.peg.and!(pegged.peg.or!(pegged.peg.literal!("F"), pegged.peg.literal!("f")), pegged.peg.or!(pegged.peg.literal!("A"), pegged.peg.literal!("a")), pegged.peg.or!(pegged.peg.literal!("L"), pegged.peg.literal!("l")), pegged.peg.or!(pegged.peg.literal!("S"), pegged.peg.literal!("s")), pegged.peg.or!(pegged.peg.literal!("E"), pegged.peg.literal!("e"))))), "Config.Bool")(p);
        }
        else
        {
            if (auto m = tuple(`Bool`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.or!(pegged.peg.and!(pegged.peg.or!(pegged.peg.literal!("T"), pegged.peg.literal!("t")), pegged.peg.or!(pegged.peg.literal!("R"), pegged.peg.literal!("r")), pegged.peg.or!(pegged.peg.literal!("U"), pegged.peg.literal!("u")), pegged.peg.or!(pegged.peg.literal!("E"), pegged.peg.literal!("e"))), pegged.peg.and!(pegged.peg.or!(pegged.peg.literal!("F"), pegged.peg.literal!("f")), pegged.peg.or!(pegged.peg.literal!("A"), pegged.peg.literal!("a")), pegged.peg.or!(pegged.peg.literal!("L"), pegged.peg.literal!("l")), pegged.peg.or!(pegged.peg.literal!("S"), pegged.peg.literal!("s")), pegged.peg.or!(pegged.peg.literal!("E"), pegged.peg.literal!("e"))))), "Config.Bool"), "Bool")(p);
                memo[tuple(`Bool`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Bool(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.or!(pegged.peg.and!(pegged.peg.or!(pegged.peg.literal!("T"), pegged.peg.literal!("t")), pegged.peg.or!(pegged.peg.literal!("R"), pegged.peg.literal!("r")), pegged.peg.or!(pegged.peg.literal!("U"), pegged.peg.literal!("u")), pegged.peg.or!(pegged.peg.literal!("E"), pegged.peg.literal!("e"))), pegged.peg.and!(pegged.peg.or!(pegged.peg.literal!("F"), pegged.peg.literal!("f")), pegged.peg.or!(pegged.peg.literal!("A"), pegged.peg.literal!("a")), pegged.peg.or!(pegged.peg.literal!("L"), pegged.peg.literal!("l")), pegged.peg.or!(pegged.peg.literal!("S"), pegged.peg.literal!("s")), pegged.peg.or!(pegged.peg.literal!("E"), pegged.peg.literal!("e"))))), "Config.Bool")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.or!(pegged.peg.and!(pegged.peg.or!(pegged.peg.literal!("T"), pegged.peg.literal!("t")), pegged.peg.or!(pegged.peg.literal!("R"), pegged.peg.literal!("r")), pegged.peg.or!(pegged.peg.literal!("U"), pegged.peg.literal!("u")), pegged.peg.or!(pegged.peg.literal!("E"), pegged.peg.literal!("e"))), pegged.peg.and!(pegged.peg.or!(pegged.peg.literal!("F"), pegged.peg.literal!("f")), pegged.peg.or!(pegged.peg.literal!("A"), pegged.peg.literal!("a")), pegged.peg.or!(pegged.peg.literal!("L"), pegged.peg.literal!("l")), pegged.peg.or!(pegged.peg.literal!("S"), pegged.peg.literal!("s")), pegged.peg.or!(pegged.peg.literal!("E"), pegged.peg.literal!("e"))))), "Config.Bool"), "Bool")(TParseTree("", false,[], s));
        }
    }
    static string Bool(GetName g)
    {
        return "Config.Bool";
    }

    static TParseTree Integer(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.or!(Hex, Dec), pegged.peg.option!(pegged.peg.keywords!("LL", "L"))), "Config.Integer")(p);
        }
        else
        {
            if (auto m = tuple(`Integer`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.or!(Hex, Dec), pegged.peg.option!(pegged.peg.keywords!("LL", "L"))), "Config.Integer"), "Integer")(p);
                memo[tuple(`Integer`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Integer(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.or!(Hex, Dec), pegged.peg.option!(pegged.peg.keywords!("LL", "L"))), "Config.Integer")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.or!(Hex, Dec), pegged.peg.option!(pegged.peg.keywords!("LL", "L"))), "Config.Integer"), "Integer")(TParseTree("", false,[], s));
        }
    }
    static string Integer(GetName g)
    {
        return "Config.Integer";
    }

    static TParseTree Hex(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.discard!(pegged.peg.literal!("0")), pegged.peg.discard!(pegged.peg.or!(pegged.peg.literal!("X"), pegged.peg.literal!("x"))), pegged.peg.oneOrMore!(hexDigit))), "Config.Hex")(p);
        }
        else
        {
            if (auto m = tuple(`Hex`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.discard!(pegged.peg.literal!("0")), pegged.peg.discard!(pegged.peg.or!(pegged.peg.literal!("X"), pegged.peg.literal!("x"))), pegged.peg.oneOrMore!(hexDigit))), "Config.Hex"), "Hex")(p);
                memo[tuple(`Hex`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Hex(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.discard!(pegged.peg.literal!("0")), pegged.peg.discard!(pegged.peg.or!(pegged.peg.literal!("X"), pegged.peg.literal!("x"))), pegged.peg.oneOrMore!(hexDigit))), "Config.Hex")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.discard!(pegged.peg.literal!("0")), pegged.peg.discard!(pegged.peg.or!(pegged.peg.literal!("X"), pegged.peg.literal!("x"))), pegged.peg.oneOrMore!(hexDigit))), "Config.Hex"), "Hex")(TParseTree("", false,[], s));
        }
    }
    static string Hex(GetName g)
    {
        return "Config.Hex";
    }

    static TParseTree Dec(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), digits)), "Config.Dec")(p);
        }
        else
        {
            if (auto m = tuple(`Dec`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), digits)), "Config.Dec"), "Dec")(p);
                memo[tuple(`Dec`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Dec(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), digits)), "Config.Dec")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), digits)), "Config.Dec"), "Dec")(TParseTree("", false,[], s));
        }
    }
    static string Dec(GetName g)
    {
        return "Config.Dec";
    }

    static TParseTree Float(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.or!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), pegged.peg.zeroOrMore!(digit), pegged.peg.keep!(pegged.peg.literal!(".")), pegged.peg.zeroOrMore!(digit), pegged.peg.option!(pegged.peg.and!(pegged.peg.or!(pegged.peg.literal!("e"), pegged.peg.literal!("E")), pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), digits))), pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), pegged.peg.oneOrMore!(digit), pegged.peg.option!(pegged.peg.and!(pegged.peg.keep!(pegged.peg.literal!(".")), pegged.peg.zeroOrMore!(digit))), pegged.peg.or!(pegged.peg.literal!("e"), pegged.peg.literal!("E")), pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), digits))), "Config.Float")(p);
        }
        else
        {
            if (auto m = tuple(`Float`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.or!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), pegged.peg.zeroOrMore!(digit), pegged.peg.keep!(pegged.peg.literal!(".")), pegged.peg.zeroOrMore!(digit), pegged.peg.option!(pegged.peg.and!(pegged.peg.or!(pegged.peg.literal!("e"), pegged.peg.literal!("E")), pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), digits))), pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), pegged.peg.oneOrMore!(digit), pegged.peg.option!(pegged.peg.and!(pegged.peg.keep!(pegged.peg.literal!(".")), pegged.peg.zeroOrMore!(digit))), pegged.peg.or!(pegged.peg.literal!("e"), pegged.peg.literal!("E")), pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), digits))), "Config.Float"), "Float")(p);
                memo[tuple(`Float`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Float(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.or!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), pegged.peg.zeroOrMore!(digit), pegged.peg.keep!(pegged.peg.literal!(".")), pegged.peg.zeroOrMore!(digit), pegged.peg.option!(pegged.peg.and!(pegged.peg.or!(pegged.peg.literal!("e"), pegged.peg.literal!("E")), pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), digits))), pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), pegged.peg.oneOrMore!(digit), pegged.peg.option!(pegged.peg.and!(pegged.peg.keep!(pegged.peg.literal!(".")), pegged.peg.zeroOrMore!(digit))), pegged.peg.or!(pegged.peg.literal!("e"), pegged.peg.literal!("E")), pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), digits))), "Config.Float")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.or!(pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), pegged.peg.zeroOrMore!(digit), pegged.peg.keep!(pegged.peg.literal!(".")), pegged.peg.zeroOrMore!(digit), pegged.peg.option!(pegged.peg.and!(pegged.peg.or!(pegged.peg.literal!("e"), pegged.peg.literal!("E")), pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), digits))), pegged.peg.and!(pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), pegged.peg.oneOrMore!(digit), pegged.peg.option!(pegged.peg.and!(pegged.peg.keep!(pegged.peg.literal!(".")), pegged.peg.zeroOrMore!(digit))), pegged.peg.or!(pegged.peg.literal!("e"), pegged.peg.literal!("E")), pegged.peg.option!(pegged.peg.or!(pegged.peg.literal!("-"), pegged.peg.literal!("+"))), digits))), "Config.Float"), "Float")(TParseTree("", false,[], s));
        }
    }
    static string Float(GetName g)
    {
        return "Config.Float";
    }

    static TParseTree StringQuot(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.discard!(doublequote), pegged.peg.zeroOrMore!(pegged.peg.or!(pegged.peg.and!(backslash, backslash), pegged.peg.and!(backslash, doublequote), pegged.peg.and!(backslash, pegged.peg.keep!(pegged.peg.literal!("f"))), pegged.peg.and!(backslash, pegged.peg.keep!(pegged.peg.literal!("n"))), pegged.peg.and!(backslash, pegged.peg.keep!(pegged.peg.literal!("r"))), pegged.peg.and!(backslash, pegged.peg.keep!(pegged.peg.literal!("t"))), pegged.peg.and!(pegged.peg.negLookahead!(doublequote), pegged.peg.negLookahead!(backslash), pegged.peg.any))), pegged.peg.discard!(doublequote))), "Config.StringQuot")(p);
        }
        else
        {
            if (auto m = tuple(`StringQuot`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.discard!(doublequote), pegged.peg.zeroOrMore!(pegged.peg.or!(pegged.peg.and!(backslash, backslash), pegged.peg.and!(backslash, doublequote), pegged.peg.and!(backslash, pegged.peg.keep!(pegged.peg.literal!("f"))), pegged.peg.and!(backslash, pegged.peg.keep!(pegged.peg.literal!("n"))), pegged.peg.and!(backslash, pegged.peg.keep!(pegged.peg.literal!("r"))), pegged.peg.and!(backslash, pegged.peg.keep!(pegged.peg.literal!("t"))), pegged.peg.and!(pegged.peg.negLookahead!(doublequote), pegged.peg.negLookahead!(backslash), pegged.peg.any))), pegged.peg.discard!(doublequote))), "Config.StringQuot"), "StringQuot")(p);
                memo[tuple(`StringQuot`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree StringQuot(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.discard!(doublequote), pegged.peg.zeroOrMore!(pegged.peg.or!(pegged.peg.and!(backslash, backslash), pegged.peg.and!(backslash, doublequote), pegged.peg.and!(backslash, pegged.peg.keep!(pegged.peg.literal!("f"))), pegged.peg.and!(backslash, pegged.peg.keep!(pegged.peg.literal!("n"))), pegged.peg.and!(backslash, pegged.peg.keep!(pegged.peg.literal!("r"))), pegged.peg.and!(backslash, pegged.peg.keep!(pegged.peg.literal!("t"))), pegged.peg.and!(pegged.peg.negLookahead!(doublequote), pegged.peg.negLookahead!(backslash), pegged.peg.any))), pegged.peg.discard!(doublequote))), "Config.StringQuot")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.discard!(doublequote), pegged.peg.zeroOrMore!(pegged.peg.or!(pegged.peg.and!(backslash, backslash), pegged.peg.and!(backslash, doublequote), pegged.peg.and!(backslash, pegged.peg.keep!(pegged.peg.literal!("f"))), pegged.peg.and!(backslash, pegged.peg.keep!(pegged.peg.literal!("n"))), pegged.peg.and!(backslash, pegged.peg.keep!(pegged.peg.literal!("r"))), pegged.peg.and!(backslash, pegged.peg.keep!(pegged.peg.literal!("t"))), pegged.peg.and!(pegged.peg.negLookahead!(doublequote), pegged.peg.negLookahead!(backslash), pegged.peg.any))), pegged.peg.discard!(doublequote))), "Config.StringQuot"), "StringQuot")(TParseTree("", false,[], s));
        }
    }
    static string StringQuot(GetName g)
    {
        return "Config.StringQuot";
    }

    static TParseTree String(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.oneOrMore!(pegged.peg.and!(StringQuot, pegged.peg.option!(spacing)))), "Config.String")(p);
        }
        else
        {
            if (auto m = tuple(`String`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.oneOrMore!(pegged.peg.and!(StringQuot, pegged.peg.option!(spacing)))), "Config.String"), "String")(p);
                memo[tuple(`String`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree String(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.oneOrMore!(pegged.peg.and!(StringQuot, pegged.peg.option!(spacing)))), "Config.String")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.oneOrMore!(pegged.peg.and!(StringQuot, pegged.peg.option!(spacing)))), "Config.String"), "String")(TParseTree("", false,[], s));
        }
    }
    static string String(GetName g)
    {
        return "Config.String";
    }

    static TParseTree opCall(TParseTree p)
    {
        TParseTree result = decimateTree(Document(p));
        result.children = [result];
        result.name = "Config";
        return result;
    }

    static TParseTree opCall(string input)
    {
        if(__ctfe)
        {
            return Config(TParseTree(``, false, [], input, 0, 0));
        }
        else
        {
            forgetMemo();
            return Config(TParseTree(``, false, [], input, 0, 0));
        }
    }
    static string opCall(GetName g)
    {
        return "Config";
    }


    static void forgetMemo()
    {
        memo = null;
    }
    }
}

alias GenericConfig!(ParseTree).Config Config;

