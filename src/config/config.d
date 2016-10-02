module config.config;

import std.typecons : BitFlags;
import std.range : isOutputRange;

import config.setting;


/// Options used by Config when writing a file
enum Option {
    AutoConvert                 = 0x01,
    SemiColonSeparators         = 0x02,
    ColonAssignmentForGroups    = 0x04,
    ColonAssignmentForNonGroups = 0x08,
    OpenBraceOnSeparateLine     = 0x10,
}

/// Main Config class
class Config
{
    import std.stdio : File;
    import std.ascii : newline;

    this() {
        _root = new GroupSetting(this, null, "");

        _options = BitFlags!Option(
            Option.SemiColonSeparators |
            Option.ColonAssignmentForGroups |
            Option.OpenBraceOnSeparateLine
        );

        _tabWidth = 2;
        _floatPrecision = 2;
    }

    @property inout(GroupSetting) root() inout { return _root; }

    @property BitFlags!Option options() const { return _options; }
    @property void options(BitFlags!Option options) { _options = options; }

    @property IntegerFormat defaultIntegerFormat() const { return _defaultIntegerFormat; }
    @property void defaultIntegerFormat(IntegerFormat format) { _defaultIntegerFormat = format; }

    @property ushort tabWidth() const { return _tabWidth; }
    @property void tabWidth(ushort val) {
        import std.algorithm : max;
        _tabWidth = max(ushort(15), val);
    }

    @property ushort floatPrecision() const { return _floatPrecision; }
    @property void floatPrecision(ushort val) { _floatPrecision = val; }


    /// read a config from an opened file
    static Config read(File configFile, in string[] includeDirs=[])
    {
        import std.array : join;
        import std.stdio : KeepTerminator;
        import config.util : stripComments, handleIncludeDirs;

        immutable config = configFile
                .byLineCopy(KeepTerminator.no, newline)
                .stripComments()
                .handleIncludeDirs(includeDirs)
                .join(newline);
        return Parser.readConfig(config);
    }

    /// read from configuration string
    static Config readString(in string configStr, string[] includeDirs=[]) {
        import std.string : lineSplitter;
        import std.array : join;
        import config.util : stripComments, handleIncludeDirs;

        immutable config = configStr
                .lineSplitter()
                .stripComments()
                .handleIncludeDirs(includeDirs)
                .join(newline);

        return Parser.readConfig(config);
    }

    /// read from configuration residing in configFile
    static Config readFile(in string configFile, string[] includeDirs=[]) {
        return read(File(configFile, "r"), includeDirs);
    }

    /// writes the configuration to a string
    override string toString()
    {
        import std.array : appender;
        auto app = appender!string();
        Writer.writeSetting(app, root, 0);
        return app.data;
    }

    /// writes the configuration to the given output range
    void writeTo(O)(O writer)
    if (isOutputRange!O)
    {
        Writer.writeSetting(writer, root, 0);
    }

    package {
        Setting makeSetting(AggregateSetting parent, string name, Type type) {
            switch(type) {
                case Type.Bool:
                case Type.Int:
                case Type.Float:
                case Type.String:
                    return new ScalarSetting(this, parent, name, type);
                case Type.Array:
                    return new ArraySetting(this, parent, name);
                case Type.List:
                    return new ListSetting(this, parent, name);
                case Type.Group:
                    return new GroupSetting(this, parent, name);
                default:
                    assert(false, "unsupported Setting type: "~type.stringof);
            }
        }
    }

    private {
        GroupSetting _root;
        BitFlags!Option _options;
        IntegerFormat _defaultIntegerFormat;
        ushort _tabWidth;
        ushort _floatPrecision;


        struct Parser
        {
            import cg = config.grammar;

            private {

                static Config readConfig(in string config)
                {
                    auto conf = new Config;
                    auto mainTree = cg.Config(config);
                    assert(mainTree.children.length == 1);
                    assert(mainTree.children[0].name == "Config.Document");
                    auto docTree = mainTree.children[0];

                    foreach (pt; docTree.children) {
                        assert(pt.name == "Config.Setting");
                        conf.root.addChild(parseSetting(conf, conf.root, pt));
                    }

                    return conf;
                }

                static Setting parseSetting(Config conf, AggregateSetting par, cg.ParseTree pt) {
                    assert(pt.name == "Config.Setting");
                    // assertions enforced by grammar
                    assert(pt.children.length == 2);
                    assert(pt.children[0].name == "Config.Name");
                    assert(pt.children[1].name == "Config.Value");

                    string name = pt.children[0].matches[0];
                    return parseValue(conf, par, name, pt.children[1]);
                }


                static Setting parseValue(Config conf, AggregateSetting par, string name, cg.ParseTree valTree) {
                    assert(valTree.name == "Config.Value");

                    switch (valTree.children[0].name) {
                        case "Config.Scalar":
                            return parseScalar(conf, par, name, valTree.children[0]);
                        case "Config.Array": {
                            auto s = new ArraySetting(conf, par, name);
                            auto ss = new Setting[valTree.children.length];
                            foreach (i, pt; valTree.children) {
                                ss[i] = parseValue(conf, s, "", pt);
                            }
                            s.setChildren(ss);
                            return s;
                        }
                        case "Config.List": {
                            auto s = new ListSetting(conf, par, name);
                            auto ss = new Setting[valTree.children.length];
                            foreach (i, pt; valTree.children) {
                                ss[i] = parseValue(conf, s, "", pt);
                            }
                            s.setChildren(ss);
                            return s;
                        }
                        case "Config.Group":
                        default: assert(false);
                    }
                }

                static Setting parseScalar(Config conf, AggregateSetting par, string name, cg.ParseTree scalTree) {
                    assert(scalTree.name == "Config.Scalar");

                    switch (scalTree.children[0].name) {
                        case "Config.Bool": {
                            import std.uni : toLower;
                            ScalarSetting s = new ScalarSetting(conf, par, name, Type.Bool);
                            if (scalTree.matches[0][0].toLower == 't') {
                                s.value = true;
                            }
                            else {
                                s.value = false;
                            }
                            return s;
                        }
                        case "Config.Integer": {
                            import std.conv : to;
                            ScalarSetting s = new ScalarSetting(conf, par, name, Type.Int);
                            if (scalTree.children[0].children[0].name == "Config.Dec") {
                                s.value = scalTree.matches[0].to!long(10);
                            }
                            else {
                                assert(scalTree.children[0].children[0].name == "Config.Hex");
                                s.value = scalTree.matches[0].to!long(16);
                            }
                            return s;
                        }
                        case "Config.Float": {
                            import std.conv : to;
                            ScalarSetting s = new ScalarSetting(conf, par, name, Type.Float);
                            s.value = scalTree.matches[0].to!double();
                            return s;
                        }
                        case "Config.String": {
                            ScalarSetting s = new ScalarSetting(conf, par, name, Type.String);
                            s.value = scalTree.matches[0];
                            return s;
                        }
                        default: assert(false);
                    }
                }

                static void validateArrayChildren(Setting[] children) {
                    import std.algorithm : each;
                    import std.exception : enforce;
                    enum seenBool   = 1;
                    enum seenInt    = 2;
                    enum seenFloat  = 4;
                    enum seenString = 8;
                    static int seen (in Type t) {
                        switch(t) {
                            case Type.Bool: return seenBool;
                            case Type.Int: return seenInt;
                            case Type.Float: return seenFloat;
                            case Type.String: return seenString;
                            default: assert(false);
                        }
                    }

                    int seenFl;
                    children.each!(c => seenFl |= seen(c.type));

                    enforce(seenFl == seenBool || seenFl == seenString || seenFl & (seenInt | seenFloat));
                    if ((seenFl & seenInt)==seenInt && (seenFl & seenFloat)==seenFloat) {
                        // mix of float and ints, convert all ints to float
                        foreach(ref c; children) {
                            if (c.type == Type.Int) {
                                auto sc = cast(ScalarSetting)c;
                                immutable val = sc.value!long;
                                sc.value = cast(double)val;
                            }
                        }
                    }
                }
            }
        }

        struct Writer
        {
            import std.range : isOutputRange, repeat, take;
            import std.range.primitives : put;
            import std.format : format;

            static void writeIndent(O)(O output, in int depth, in int width)
            in {
                assert(depth > 1);
            }
            body {
                put(output, repeat(' ').take((depth-1)*width));
            }

            static void writeValue(O)(O output, in Setting setting, in int depth)
            {
                if (setting.isScalar)
                {
                    writeScalarValue(output, setting.asScalar);
                }
                else if (setting.isArray)
                {
                    writeArrayValue(output, setting.asArray, depth);
                }
                else if (setting.isList)
                {
                    writeListValue(output, setting.asList, depth);
                }
                else if (setting.isGroup)
                {
                    writeGroupValue(output, setting.asGroup, depth);
                }
                else assert(false);
            }

            static void writeScalarValue(O)(O output, in ScalarSetting setting)
            {
                switch(setting.type)
                {
                    case Type.Bool: {
                        put(output, setting.value!bool ? "true" : "false");
                        break;
                    }
                    case Type.Int: {
                        immutable val = setting.value!long;
                        string suffix = (val > int.max || val < int.min) ? "L" : "";
                        string fmt = (setting.integerFormat == IntegerFormat.Hex) ? "0x%X%s" : "%d%s";
                        put(output, format(fmt, val, suffix));
                        break;
                    }
                    case Type.Float: {
                        import std.uni : toLower;
                        import std.algorithm : canFind;
                        string fval = format("%*f", setting.config.floatPrecision, setting.value!double);
                        if (!fval.canFind('.') && !fval.toLower.canFind('e')) fval ~= ".0";
                        put(output, fval);
                        break;
                    }
                    case Type.String: {
                        import std.uni : isControl;
                        put(output, '"');
                        foreach(c; setting.value!string)
                        {
                            switch(c)
                            {
                                case '"':
                                    put(output, `\"`); break;
                                case '\\':
                                    put(output, `\\`); break;
                                case '\n':
                                    put(output, "\\n"); break;
                                case '\r':
                                    put(output, "\\r"); break;
                                case '\f':
                                    put(output, "\\f"); break;
                                case '\t':
                                    put(output, "\\t"); break;
                                default: {
                                    if (isControl(c))
                                    {
                                        put(output, format("\\x%02X", c));
                                    }
                                    else
                                    {
                                        put(output, c);
                                    }
                                    break;
                                }
                            }
                        }
                        put(output, '"');
                        break;
                    }
                    default: assert(false);
                }
            }

            static void writeArrayValue(O)(O output, in ArraySetting setting, int depth)
            {
                put(output, "[ ");
                writeListContent(output, setting, depth);
                put(output, ']');
            }

            static void writeListValue(O)(O output, in ListSetting setting, int depth)
            {
                put(output, "( ");
                writeListContent(output, setting, depth);
                put(output, ')');
            }

            static void writeListContent(O)(O output, in AggregateSetting setting, in int depth)
            {
                auto children = setting.children;
                foreach (i, s; children)
                {
                    writeValue(output, s, depth+1);
                    if (i < children.length-1)  put(output, ',');
                    put(output, ' ');
                }
            }

            static void writeGroupValue(O)(O output, in GroupSetting setting, in int depth)
            {
                if (depth > 0)
                {
                    if (setting.config.options & Option.OpenBraceOnSeparateLine)
                    {
                        put(output, newline);
                        if (depth > 1) writeIndent(output, depth, setting.config.tabWidth);
                    }
                    put(output, "{"~newline);
                }

                foreach (s; setting.children)
                {
                    writeSetting(output, s, depth+1);
                }

                if (depth > 1) writeIndent(output, depth, setting.config.tabWidth);
                if (depth > 0) put(output, '}');
            }

            static void writeSetting(O)(O output, in Setting setting, in int depth)
            {
                auto config = setting.config;
                auto groupAssignChar = (config.options & Option.ColonAssignmentForGroups) ? ':' : '=';
                auto nonGroupAssignChar = (config.options & Option.ColonAssignmentForNonGroups) ? ':' : '=';

                if (depth > 1) writeIndent(output, depth, config.tabWidth);

                if (setting.name.length)
                {
                    put(output, format("%s %s ",
                        setting.name, setting.isGroup ? groupAssignChar : nonGroupAssignChar
                    ));
                }

                writeValue(output, setting, depth);

                if (depth > 0)
                {
                    if (config.options & Option.SemiColonSeparators)
                        put(output, ';');
                    put(output, newline);
                }
            }
        }
    }
}



package enum pathTok = ".:/";


version(unittest)
{
    immutable testFiles = [
        [ import("input_0.cfg"), import("output_0.cfg") ],
        [ import("input_1.cfg"), import("output_1.cfg") ],
        [ import("input_2.cfg"), import("output_2.cfg") ],
        [ import("input_3.cfg"), import("output_3.cfg") ],
        [ import("input_4.cfg"), import("output_4.cfg") ],
        [ import("input_5.cfg"), import("output_5.cfg") ],
    ];

    immutable testErrFiles = [
        [ import("bad_input_0.cfg"), import("parse_error_0.txt") ],
        [ import("bad_input_1.cfg"), import("parse_error_1.txt") ],
    ];


    void parseAndCompare(string input, string expected)
    {
        import std.format : format;

        auto conf = Config.readString(input, ["."]);
        auto res = conf.toString();
        assert(expected == res, format(
            "parseAndCompare failed.\ninput:\n%s\nresult:\n%s\nexpected:\n%s\n",
            input, res, expected
        ));
    }

    void parseFileAndCompare(string input, string expected)
    {
        import std.format : format;
        import std.file : write, remove;

        scope(exit) remove("input.cfg");
        write("input.cfg", input);

        auto conf = Config.readFile("input.cfg", ["."]);
        auto res = conf.toString();
        assert(expected == res, format(
            "parseAndCompare failed.\ninput:\n%s\nresult:\n%s\nexpected:\n%s\n",
            input, res, expected
        ));
    }


    unittest {
        import std.file : write, remove;

        scope(exit) remove("more.cfg");
        write("more.cfg", import("more.cfg"));

        foreach (tf; testFiles)
        {
            parseAndCompare(tf[0], tf[1]);
        }

        parseFileAndCompare(testFiles[2][0], testFiles[2][1]);
    }
}

