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

    @property string includeDir() const { return _includeDir; }
    @property void includeDir(string dir) { _includeDir = dir; }

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
        Setting _root;
        string _includeDir;
        BitFlags!Option _options;
        IntegerFormat _defaultIntegerFormat;
        ushort _tabWidth;
        ushort _floatPrecision;
    }
}


package enum pathTok = ".:/";