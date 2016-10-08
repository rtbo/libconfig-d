module config.config;

import std.typecons : BitFlags, Nullable;
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

class ConfigException : Exception
{
    this(in string msg)
    {
        super(msg);
    }
}


class InvalidConfigInput : ConfigException
{
    this(in string input, in string errorMsg)
    {
        this.input = input;
        this.errorMsg = errorMsg;
        super("Invalid config input. Error:\n"~errorMsg~"\nInput:\n"~prependLineNumbers(input));
    }

    string input;
    string errorMsg;
}

class InconsistentConfigState : ConfigException
{
    this(in string msg)
    {
        super(msg);
    }
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

    inout(Setting) lookUp(in string name) inout
    {
        return root.lookUp(name);
    }

    Nullable!T lookUpValue(T)(in string name) const
    {
        return root.lookUpValue!T(name);
    }

    bool remove(in string path)
    {
        return root.remove(path);
    }

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

            static Config readConfig(in string config)
            {
                import std.exception : enforce;

                auto conf = new Config;
                auto mainTree = cg.Config(config);
                enforce(mainTree.successful, new InvalidConfigInput(config, mainTree.failMsg));

                assert(mainTree.children.length == 1);
                assert(mainTree.children[0].name == "Config.Document");
                auto docTree = mainTree.children[0];

                foreach (pt; docTree.children) {
                    assert(pt.name == "Config.Setting");
                    conf.root.addChild(parseSetting(conf, conf.root, pt));
                }

                return conf;
            }

            static Setting parseSetting(Config conf, AggregateSetting par, cg.ParseTree pt)
            {
                assert(pt.name == "Config.Setting");

                // assertions enforced by grammar
                assert(pt.children.length == 2);
                assert(pt.children[0].name == "Config.Name");
                assert(pt.children[1].name == "Config.Value");

                string name = pt.children[0].matches[0];
                return parseValue(conf, par, name, pt.children[1]);
            }


            static Setting parseValue(Config conf, AggregateSetting par, string name, cg.ParseTree valTree)
            {
                assert(valTree.name == "Config.Value");

                valTree = valTree.children[0];
                switch (valTree.name) {
                    case "Config.Scalar":
                        return parseScalar(conf, par, name, valTree);
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
                    case "Config.Group": {
                        auto s = new GroupSetting(conf, par, name);
                        auto ss = new Setting[valTree.children.length];
                        foreach (i, pt; valTree.children) {
                            ss[i] = parseSetting(conf, s, pt);
                        }
                        s.setChildren(ss);
                        return s;
                    }
                    default: assert(false);
                }
            }

            static Setting parseScalar(Config conf, AggregateSetting par, string name, cg.ParseTree scalTree)
            {
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

                enforce(
                    seenFl == seenBool || seenFl == seenString || seenFl & (seenInt | seenFloat),
                    new InconsistentConfigState("Array with different types")
                );
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
                        string fval = format("%.*f", setting.config.floatPrecision, setting.value!double);
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



private string prependLineNumbers(string text) {
    import std.string : splitLines, KeepTerminator;
    import std.format : format;
    import std.math : log10;

    auto lines = text.splitLines(KeepTerminator.yes);
    immutable width = 1 + cast(int)log10(lines.length);
    string res;
    foreach(i, l; lines) {
        res ~= format("%*s. %s", width, i+1, l);
    }
    return res;
}
