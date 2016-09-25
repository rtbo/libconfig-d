module config.setting;

import config.config : Config;

import std.traits : isNumeric, isSomeString;
import std.typecons : Nullable;

/// The type of a Setting
enum Type {
    None, Int, Float, String, Bool, Group, Array, List
}

/// Integer format used when writing a file
enum IntegerFormat {
    Dec, Hex
}

/// template that checks if T is a possible scalar candidate
enum isScalarCandidate(T) = is(T == bool) || isIntegral!T || isFloatingPoint!T || isSomeString!T;


/// returns true if a setting with Type type can hold a value of type T.
bool isScalarCompatible(T)(in Type type) pure {
    switch(type) {
        case Type.Bool:
            return is(T == bool);
        case Type.Int:
        case Type.Float:
            return isNumeric!T;
        case Type.String:
            return isSomeString!T;
        default:
            return false;
    }
}

template scalarType(T)
if (isScalarCandidate!T)
{
    static if (is(T == bool)) {
        enum scalarType = Type.Bool;
    }
    else static if (isIntegral!T) {
        enum scalarType = Type.Int;
    }
    else static if (isFloatingPoint!T) {
        enum scalarType = Type.Float;
    }
    else static if (isSomeString!T) {
        enum scalarType = Type.String;
    }
}


@property bool isScalar(in Type type)
{
    return cast(int)type > Type.None && cast(int)type < Type.Group;
}
@property bool isAggregate(in Type type)
{
    return cast(int)type >= Type.Group;
}
@property bool isNumber(in Type type)
{
    return type == Type.Int || type == Type.Float;
}


/// Setting type. Has a name and value which can be of any of Type
abstract class Setting {

    @property string name() const { return _name; }
    @property Type type() const { return _type; }

    @property inout(Config) config() inout { return _config; }
    @property inout(AggregateSetting) parent() inout { return _parent; }

    inout(Setting) child(in size_t idx) inout { return null; }
    inout(Setting) child(in string name) inout { return null; }
    inout(Setting) lookUp(in string path) inout { return null; }

    bool lookUpValue(T)(in string path, ref T value) const {
        if (auto s = lookUp(path)) {
            if (auto ss = s.asScalar) {
                value = ss.value!T;
                return true;
            }
        }
        return false;
    }

    @property size_t index() const {
        import std.algorithm : countUntil;
        if (!parent) return -1;
        return countUntil(parent._children, this);
    }

    @property bool isGroup() const {
        return _type == Type.Group;
    }
    @property bool isArray() const {
        return _type == Type.Array;
    }
    @property bool isList() const {
        return _type == Type.List;
    }
    @property bool isScalar() const {
        return _type.isScalar;
    }
    @property bool isAggregate() const {
        return _type.isAggregate;
    }
    @property bool isNumber() const {
        return _type.isNumber;
    }
    @property bool isRoot() const {
        return _parent is null;
    }

    @property auto asScalar() inout {
        return cast(ScalarSetting)this;
    }
    @property auto asArray() inout {
        return cast(ArraySetting)this;
    }
    @property auto asList() inout {
        return cast(ListSetting)this;
    }
    @property auto asGroup() inout {
        return cast(GroupSetting)this;
    }

    @property IntegerFormat integerFormat() const {
        if (!_integerFormat.isNull) return _integerFormat;
        if (parent) return parent.integerFormat;
        return config.defaultIntegerFormat;
    }
    @property void integerFormat(Nullable!IntegerFormat format) {
        _integerFormat = format;
    }

    package {
        this(Config config, AggregateSetting parent, string name, Type type) {
            _config = config;
            _parent = parent;
            _name = name;
            _type = type;
        }
    }

    private {
        string _name;
        Type _type;
        Nullable!IntegerFormat _integerFormat;

        Config _config;
        AggregateSetting _parent;
        string _file;
        int _lineNumber;
    }
}

/// Setting that holds a scalar value that can be one of Bool, Float, Integer or String
class ScalarSetting : Setting {

    @property T value(T)() const if (isScalarCandidate!T) {
        enforce(_type.isScalarCompatible!T);
        return _value.coerce!T;
    }

    @property void value(T)(T val) if (isScalarCandidate!T) {
        if (isAggregate) orpheanChildren();
        _type = scalarType!T;
        _value = val;
    }


    package {
        this(Config config, AggregateSetting parent, string name, Type type) {
            assert(type.isScalar);
            super(config, parent, name, type);
        }
    }
    private {
        import std.variant : Algebraic;

        alias Value = Algebraic!(bool, long, double, string);
        Value _value;
    }
}


class AggregateSetting : Setting {


    override inout(Setting) child(in size_t idx) inout {
        if (idx >= _children.length) return null;
        return _children[idx];
    }

    override inout(Setting) lookUp(in string name) inout {
        import config.config : pathTok;
        import config.util : findSplitAmong;
        import std.range : empty;

        if (name.empty) return this;

        immutable split = name.findSplitAmong(pathTok);

        auto s = getChild(split[0]);

        if (!split[2].empty && s) return s.lookUp(split[2]);
        return s;
    }

    package {
        this(Config config, AggregateSetting parent, string name, Type type) {
            assert(type.isAggregate);
            super(config, parent, name, type);
        }
    }

    private {

        Setting addChild(string name, Type type) {
            if (!validateName(name)) return null;
            auto s = config.makeSetting(this, name, type);
            if (s) _children ~= s;
            return s;
        }

        inout(Setting) getChild(string name) inout {
            import std.algorithm : find;
            import std.exception : enforce;
            import std.range : empty;
            import std.conv : to;

            auto square = find(name, '[');
            auto childName = name[0 .. $-square.length];
            auto child = super.child(childName);

            if (square.empty) return child;

            assert(square[0] == '[');
            enforce(square[$-1] == ']');

            immutable ind = to!size_t(name[1 .. $-1]);
            return child.child(ind);
        }

        Setting[] _children;
    }
}


class ArraySetting : AggregateSetting {

    Setting add(Type type) {
        import std.exception : enforce;
        enforce(type.isScalar);
        enforce(_children.length == 0 || _children[0].type == type);

        return addChild("", type);
    }

    package {
        this(Config config, AggregateSetting parent, string name) {
            super(config, parent, name, Type.Array);
        }
    }
}


class ListSetting : AggregateSetting {

    Setting add(Type type) {
        return addChild("", type);
    }

    package {
        this(Config config, AggregateSetting parent, string name) {
            super(config, parent, name, Type.List);
        }
    }
}


class GroupSetting : AggregateSetting {

    override inout(Setting) child(in string name) inout {
        foreach (c; _children) {
            if (c.name == name) return c;
        }
        return null;
    }

    Setting add(string name, Type type) {
        return addChild(name, type);
    }

    package {
        this(Config config, AggregateSetting parent, string name) {
            super(config, parent, name, Type.Group);
        }
    }
}


private:

bool validateName(string name) {
    import std.utf : byDchar;
    import std.uni : isAlpha;
    import std.ascii : isDigit;
    import std.algorithm : canFind;

    auto dec = name.byDchar;

    if (!dec.front.isAlpha && dec.front != '*') return false;
    dec.popFront();

    foreach(dchar c; dec) {
        if (!c.isAlpha && !c.isDigit && !"*_-"d.canFind(c)) {
            return false;
        }
    }
    return true;
}