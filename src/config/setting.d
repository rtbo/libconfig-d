module config.setting;

import config.config : Config, InconsistentConfigState;
import config.util : unsafeCast;

import std.traits : isIntegral, isFloatingPoint, isSomeString;
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
            return isIntegral!T;
        case Type.Float:
            return isFloatingPoint!T;
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

template TypedSetting(Type type)
{
    static if (type == Type.Bool || type == Type.Int || type == Type.Float || type == Type.String)
    {
        alias TypedSetting = ScalarSetting;
    }
    else static if (type == Type.Array)
    {
        alias TypedSetting = ArraySetting;
    }
    else static if (type == Type.List)
    {
        alias TypedSetting = ListSetting;
    }
    else static if (type == Type.Group)
    {
        alias TypedSetting = GroupSetting;
    }
    else static assert(false);
}

/// Setting type. Has a name and value which can be of any of Type
abstract class Setting {

    @property string name() const { return _name; }
    @property Type type() const { return _type; }

    @property inout(Config) config() inout { return _config; }
    @property inout(AggregateSetting) parent() inout { return _parent; }

    inout(Setting) child(in size_t idx) inout { return null; }
    inout(Setting) child(in string name) inout { return null; }
    @property inout(Setting)[] children() inout { return []; }

    bool remove(in size_t idx) { return false; }
    bool remove(in string path) { return false; }

    inout(Setting) lookUp(in string path) inout { return null; }
    Nullable!T lookUpValue(T)(in string path) const {
        if (auto s = lookUp(path)) {
            if (auto ss = s.asScalar) {
                return Nullable!T(ss.value!T);
            }
        }
        return Nullable!T.init;
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
    @property auto as(Type t)() inout {
        return cast(TypedSetting!t)this;
    }

    @property IntegerFormat integerFormat() const {
        if (!_integerFormat.isNull) return _integerFormat.get;
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

    @property T value(T)() const
    if (isScalarCandidate!T)
    {
        import std.exception : enforce;
        import std.conv : to;

        static if (isIntegral!T)
        {
            auto val = _value.get!long;
            static if (!is(T == long) && T.sizeof<=long.sizeof)
            {
                enforce(val >= T.min && val <= T.max,
                        "cannot cast "~val.to!string~" to "~T.stringof);
            }
            return cast(T)val;
        }
        else static if (isFloatingPoint!T)
        {
            auto val = _value.get!double;
            static if (!is(T == double) && T.sizeof<double.sizeof) // should be float unless a half type pops up
            {
                import std.math : abs;
                enforce(abs(val) >= T.min_normal && abs(val) <= T.max,
                        "cannot cast "~val.to!string~" to "~T.stringof);
            }
            return cast(T)val;
        }
        else static if (isSomeString!T)
        {
            import std.conv : to;
            return (_value.get!string).to!T;
        }
        else static if (is(T == bool)) {
            return _value.get!T;
        }
        else static assert (false);
    }

    @property void value(T)(T val)
    if (isScalarCandidate!T)
    {
        _type = scalarType!T;
        static if (isIntegral!T)
        {
            static if (!is(T == long) && T.sizeof>=long.sizeof)
            {
                enforce(val >= long.min && val <= long.max,
                        "cannot cast "~val.to!string~" to long");
            }
            _value = cast(long)val;
        }
        else static if (isFloatingPoint!T)
        {
            static if (T.sizeof>double.sizeof)
            {
                import std.math : abs;
                enforce(abs(val) >= double.min_normal && abs(val) <= double.max,
                        "cannot cast "~val.to!string~" to double");
            }
            _value = cast(double)val;
        }
        else static if (isSomeString!T)
        {
            import std.conv : to;
            _value = val.to!string;
        }
        else static if (is(T == bool))
        {
            _value = val;
        }
        else static assert(false);
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


    override inout(Setting) child(in size_t idx) inout
    {
        if (idx >= _children.length) return null;
        return _children[idx];
    }

    override inout(Setting) child(in string name) inout
    {
        import std.exception : enforce;
        enforce(type == Type.Group, "only GroupSetting can have named children");
        foreach (c; _children) {
            if (c.name == name) return c;
        }
        return null;
    }

    override @property inout(Setting)[] children() inout
    {
        return _children;
    }

    override bool remove(in size_t idx) {
        import std.algorithm : remove;

        size_t origLen = _children.length;
        _children = remove(_children, idx);
        return origLen != _children.length;
    }

    override bool remove(in string path) {
        import config.config : pathTok;
        import config.util : findSplitAmong;
        import std.range : empty;

        if (path.empty) return false;

        immutable split = path.findSplitAmong(pathTok);

        auto s = getChild(split[0]);
        if (!s) return false;

        if (!split[2].empty) {
            return s.remove(split[2]);
        }
        else {
            import std.algorithm : remove;
            auto origLen = _children.length;
            _children = remove!(c => c is s)(_children);
            return _children.length != origLen;
        }
    }

    override inout(Setting) lookUp(in string name) inout {
        import config.config : pathTok;
        import config.util : findSplitAmong;
        import std.range : empty;

        if (name.empty) return this;

        immutable split = name.findSplitAmong(pathTok);
        auto s = getChild(split[0]);
        if (!split[2].empty && s) return s.lookUp(split[2]);
        else return s;
    }

    package {
        this(Config config, AggregateSetting parent, string name, Type type) {
            assert(type.isAggregate);
            super(config, parent, name, type);
        }

        void addChild(Setting child) {
            assert(child.config is config && child.parent is this);
            debug {
                if (type == Type.Group) {
                    import std.algorithm : map, canFind;
                    assert(!_children.map!(c => c.name).canFind(child.name));
                }
            }
            _children ~= child;
        }

        void setChildren(Setting[] children) {
            import std.algorithm : map, all;
            import std.exception : enforce;
            assert(children.map!(c => c.config).all!(cf => cf == config));
            assert(children.map!(c => c.parent).all!(p => p == this));

            if (type == Type.Group) {
                bool[string] seen;
                foreach (c; children) {
                    enforce(!(c.name in seen),
                            new InconsistentConfigState("more than one child named \""~c.name~
                            "\" in GroupSetting \""~name~"\""));
                    seen[c.name] = true;
                }
            }

            _children = children;
        }
    }

    private {

        Setting addChild(string name, Type type) {
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
            auto child = child(childName);

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

    auto add(Type type)() {
        import std.exception : enforce;
        static assert(type.isScalar);
        enforce(_children.length == 0 || _children[0].type == type);

        return unsafeCast!(TypedSetting!type)(addChild("", type));
    }

    ScalarSetting addScalar(T)(in T value)
    if (isScalarCandidate!T)
    {
        import std.exception : enforce;
        immutable type = scalarType!T;
        enforce(_children.length == 0 || _children[0].type == type);

        auto ss = unsafeCast!(ScalarSetting)(addChild("", type));
        ss.value = value;
        return ss;
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

    auto add(Type type)()
    {
        return unsafeCast!(TypedSetting!type)(addChild("", type));
    }

    ScalarSetting addScalar(T)(in T value)
    if (isScalarCandidate!T)
    {
        auto ss = unsafeCast!(ScalarSetting)(addChild("", scalarType!T));
        ss.value = value;
        return ss;
    }

    package {
        this(Config config, AggregateSetting parent, string name) {
            super(config, parent, name, Type.List);
        }
    }
}


class GroupSetting : AggregateSetting {

    Setting add(in string name, in Type type) {
        import std.exception : enforce;
        enforce(validateName(name));
        enforce(!child(name));
        return addChild(name, type);
    }

    auto add(Type type)(in string name)
    {
        import std.exception : enforce;
        enforce(validateName(name));
        enforce(!child(name));
        return unsafeCast!(TypedSetting!type)(addChild(name, type));
    }

    ScalarSetting addScalar(T)(in string name, in T value)
    if (isScalarCandidate!T)
    {
        import std.exception : enforce;
        enforce(validateName(name));
        enforce(!child(name));

        auto ss = unsafeCast!(ScalarSetting)(addChild(name, scalarType!T));
        ss.value = value;
        return ss;
    }

    package {
        this(Config config, AggregateSetting parent, string name) {
            super(config, parent, name, Type.Group);
        }
    }
}


private:

bool validateName(in string name) pure {
    import std.utf : byDchar;
    import std.uni : isAlpha;
    import std.ascii : isDigit;
    import std.algorithm : canFind;

    if (name.length == 0) return false;

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