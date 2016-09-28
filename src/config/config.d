module config.config;

import config.setting;

import std.typecons : BitFlags;


/// Options used by Config when writing a file
enum Option {
    AutoConvert                 = 0x01,
    SemiColonSeparators         = 0x02,
    ColonAssignmentForGroups    = 0x04,
    ColonAssignmentForNonGroups = 0x08,
    OpenBraceOnSeparateLine     = 0x10,
}

/// Main Config class
class Config {

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
    }
}


struct ConfigParser {
    import cg = config.grammar;

    static Config read(string config) {

        auto conf = new Config;
        auto mainTree = cg.Config(config);
        assert(mainTree.children.length == 1);
        assert(mainTree.children[0].name == "Document");
        auto docTree = mainTree.children[0];

        foreach (pt; docTree.children) {
            if (pt.name == "Setting") {
                conf.root.addChild(parseSetting(conf, conf.root, pt));
            }
        }

        return conf;
    }



    private {

        static Setting parseSetting(Config conf, AggregateSetting par, cg.ParseTree pt) {
            assert(pt.name == "Setting");
            // assertions enforced by grammar
            assert(pt.children.length == 2);
            assert(pt.children[0].name == "Name");
            assert(pt.children[1].name == "Value");

            string name = pt.children[0].matches[0];
            return parseValue(conf, par, name, pt.children[1]);
        }

        static Setting parseValue(Config conf, AggregateSetting par, string name, cg.ParseTree valTree) {
            assert(valTree.name == "Value");

            switch (valTree.children[0].name) {
                case "Scalar":
                    return parseScalar(conf, par, name, valTree.children[0]);
                case "Array": {
                    auto s = new ArraySetting(conf, par, name);
                    auto ss = new Setting[valTree.children.length];
                    foreach (i, pt; valTree.children) {
                        ss[i] = parseValue(conf, s, "", pt);
                    }
                    s.setChildren(ss);
                    return s;
                }
                case "List": {
                    auto s = new ListSetting(conf, par, name);
                    auto ss = new Setting[valTree.children.length];
                    foreach (i, pt; valTree.children) {
                        ss[i] = parseValue(conf, s, "", pt);
                    }
                    s.setChildren(ss);
                    return s;
                }
                case "Group":
                default: assert(false);
            }
        }

        static Setting parseScalar(Config conf, AggregateSetting par, string name, cg.ParseTree scalTree) {
            assert(scalTree.name == "Scalar");

            switch (scalTree.children[0].name) {
                case "Bool": {
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
                case "Integer": {
                    import std.conv : to;
                    ScalarSetting s = new ScalarSetting(conf, par, name, Type.Int);
                    if (scalTree.children[0].children[0].name == "Dec") {
                        s.value = scalTree.matches[0].to!long(10);
                    }
                    else {
                        assert(scalTree.children[0].children[0].name == "Hex");
                        s.value = scalTree.matches[0].to!long(16);
                    }
                    return s;
                }
                case "Float": {
                    import std.conv : to;
                    ScalarSetting s = new ScalarSetting(conf, par, name, Type.Float);
                    s.value = scalTree.matches[0].to!double();
                    return s;
                }
                case "String": {
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


package enum pathTok = ".:/";

unittest {
    import cg = config.grammar;
    import std.stdio;
    auto c = cg.Config(
        "othername = 123456\n"
        "name = ( true, 0xDEADBEEF, 343, 0.656 )\n"
    );
    //auto c = cg.Config("name = 0xDEADBEEF");
    writeln(c);
}
