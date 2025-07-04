module config.util;

import std.range.primitives;
import std.traits : isSomeString, isSomeChar, Unqual;


/// down cast of a reference to a child class reference
/// runtime check is disabled in release build
U unsafeCast(U, T)(T obj)
        if ((is(T==class) || is(T==interface)) &&
            (is(U==class) || is(U==interface)) &&
            is(U : T))
in {
    assert(obj);
}
do {
    debug {
        auto uObj = cast(U)obj;
        assert(uObj, "unsafeCast from "~T.stringof~" to "~U.stringof~" failed");
        return uObj;
    }
    else {
        static if (is(T == interface) && is(U == class)) {
            return cast(U)(cast(void*)(cast(Object)obj));
        }
        else {
            return cast(U)(cast(void*)obj);
        }
    }
}

/// ditto
const(U) unsafeCast(U, T)(const(T) obj)
        if ((is(T==class) || is(T==interface)) &&
            (is(U==class) || is(U==interface)) &&
            is(U : T))
in {
    assert(obj);
}
do {
    debug {
        auto uObj = cast(const(U))obj;
        assert(uObj, "unsafeCast from "~T.stringof~" to "~U.stringof~" failed");
        return uObj;
    }
    else {
        static if (is(T == interface) && is(U == class)) {
            return cast(const(U))(cast(const(void*))(cast(const(Object))obj));
        }
        else {
            return cast(const(U))(cast(const(void*))obj);
        }
    }
}


auto findSplitAmong(alias pred="a == b", R1, R2)(R1 seq, R2 choices)
if (isForwardRange!R1 && isForwardRange!R2)
{
    static struct Result(S1, S2, S3)
    if (isForwardRange!S1 && isForwardRange!S2 && isForwardRange!S3)
    {
        import std.typecons : Tuple;

        this(S1 pre, S2 separator, S3 post)
        {
            asTuple = typeof(asTuple)(pre, separator, post);
        }

        bool opCast(T : bool)()
        {
            return !asTuple[1].empty;
        }

        alias asTuple this;
        Tuple!(S1, S2, S3) asTuple;
    }

    auto makeResult(S1, S2, S3)(S1 s1, S2 s2, S3 s3) {
        return Result!(S1, S2, S3)(s1, s2, s3);
    }

    static if (isSomeString!R1 && isSomeString!R2 || isRandomAccessRange!R1 && hasLength!R2)
    {
        import std.algorithm : findAmong;

        immutable balance = findAmong!pred(seq, choices);
        immutable pos1 = seq.length - balance.length;
        immutable pos2 = balance.empty ? pos1 : pos1 + 1;
        return makeResult(seq[0 .. pos1], seq[pos1 .. pos2], seq[pos2 .. $]);
    }
    else
    {
        import std.range : takeExactly, takeOne;
        import std.functional : binaryFun;

        auto original = seq.save;
        size_t pos;

        seqLoop: while (!seq.empty) {
            auto sf = seq.front;
            auto c = choices.save;
            while(!c.empty) {
                if (binaryFun!pred(sf, c.front)) {
                    break seqLoop;
                }
                c.popFront();
            }
            seq.popFront();
            ++pos;
        }

        auto right = seq.save;
        if (!right.empty) right.popFront();
        return makeResult ( takeExactly(original, pos), takeOne(seq), right );
    }
}


unittest {
    {
        auto name = "name1.name2";

        auto split1 = name.findSplitAmong(":./");
        assert(split1[0] == "name1");
        assert(split1[1] == ".");
        assert(split1[2] == "name2");

        auto split2 = name.findSplitAmong(":-/");
        assert(split2[0] == "name1.name2");
        assert(split2[1] == "");
        assert(split2[2] == "");
    }
    {
        import std.algorithm : equal;

        static struct StrFwdRange {
            string s;
            @property auto empty() const { return s.length == 0; }
            @property auto front() const { return s[0]; }
            void popFront() { s = s[1 .. $]; }
            @property auto save() const { return StrFwdRange(s); }
        }
        static assert(isForwardRange!StrFwdRange);

        auto name = StrFwdRange("name1.name2");

        auto split1 = name.findSplitAmong(StrFwdRange(":./"));
        assert(equal(split1[0], "name1"));
        assert(equal(split1[1], "."));
        assert(equal(split1[2], "name2"));

        auto split2 = name.findSplitAmong(":-/");
        assert(equal(split2[0], "name1.name2"));
        assert(equal(split2[1], ""));
        assert(equal(split2[2], ""));
    }
}


/// strip libconfig comments on a char by char basis
auto stripComments(R)(R input)
if (isInputRange!R && isSomeChar!(ElementType!R))
{
    struct Result
    {
        R _input;
        ElementType!R[] _lookAhead;

        this(R input)
        {
            _input = input;
            check();
        }

        private this (R input, ElementType!R[] lookAhead)
        {
            _input = input;
            _lookAhead = lookAhead;
        }

        @property auto save()
        {
            return Result(_input.save, _lookAhead.dup);
        }

        @property bool empty()
        {
            return _lookAhead.empty && _input.empty;
        }

        @property auto ref front()
        {
            if (_lookAhead.length) return _lookAhead[0];
            else return _input.front;
        }

        void popFront()
        {
            if (_lookAhead.empty)
            {
                _input.popFront();
                check();
            }
            else _lookAhead = _lookAhead[1 .. $];
        }

        private void check()
        {
            assert(_lookAhead.empty);

            if (_input.empty) return;
            else if (_input.front == '#') popUntilEol();
            else if (_input.front == '/')
            {
                immutable keep = _input.front;
                _input.popFront();

                if (_input.empty) _lookAhead = [keep];
                else if (_input.front == '/') popUntilEol();
                else if (_input.front == '*') popUntilEndBlock();
                else _lookAhead = [keep];
            }
        }

        private void popUntilEol()
        {
            do {
                _input.popFront();
            }
            while (!_input.empty && !(_input.front == '\r' || _input.front == '\n'));
        }

        private void popUntilEndBlock()
        {
            while (1) {
                do {
                    _input.popFront();
                    if (_input.empty) {
                        throw new Exception("comment block not closed");
                    }
                }
                while (_input.front != '*');

                _input.popFront();
                if (_input.empty) {
                    throw new Exception("comment block not closed");
                }
                if (_input.front == '/') {
                    _input.popFront();
                    break;
                }
            }
        }
    }

    return Result(input);
}



/// strip libconfig comments on a line by line basis
auto stripComments(R)(R input)
if (isInputRange!R && isSomeString!(ElementType!R))
{
    alias StringT = ElementType!R;
    alias CharT = Unqual!(typeof(StringT.init[0]));


    struct Result
    {
        R _input;
        StringT _buf;
        bool _inBlock;
        int count;

        this (R input)
        {
            _input = input;
            fetch();
        }

        this (R input, StringT buf, bool inBlock)
        {
            _input = input;
            _buf = buf;
            _inBlock = inBlock;
        }

        static if (isForwardRange!R)
        {
            @property auto save()
            {
                return Result(_input.save, (_buf is null) ? null : _buf.dup, _inBlock);
            }
        }

        @property bool empty()
        {
            return _buf is null;
        }

        @property auto front()
        {
            return _buf;
        }

        void popFront()
        {
            _buf = null;
            if (!_input.empty) {
                _input.popFront();
                fetch();
            }
        }

        private void fetch()
        {
            import std.algorithm : find, canFind;

            if (_input.empty) return;

            auto line = _input.front;
            assert(!line.canFind("\n"), "pass stripComments on a range of lines");
            typeof(line) left;
            typeof(line) right = line[];

            while (1) {
                immutable len = line.length;

                if (_inBlock) {
                    immutable end = right.find("*/");
                    if (!end.empty) {
                        line = left ~ end[2 .. $];
                        _inBlock = false;
                    }
                    else
                    {
                        line = left[];
                    }
                }
                else {
                    immutable cmtHash = line.find("#");
                    immutable cmtCpp = line.find("//");
                    immutable cmtLine = cmtHash.length > cmtCpp.length ? cmtHash : cmtCpp;
                    immutable cmtBlock = line.find("/*");

                    if (!cmtLine.empty || !cmtBlock.empty)
                    {
                        if (cmtBlock.length > cmtLine.length)
                        {
                            line = line[0 .. $-cmtBlock.length];
                            right = cmtBlock[];
                            _inBlock = true;
                        }
                        else
                        {
                            line = line[0 .. $-cmtLine.length];
                        }
                    }
                    left = line[];
                }

                if (len == line.length) break;
            }

            _buf ~= line;
            if (_buf is null) _buf = ""; // empty line "" must not be null _buf (because that means end of range)!

            if (_inBlock) {
                _input.popFront();
                if (_input.empty) throw new Exception("comment block not closed");
                else fetch();
            }
        }
    }

    return Result(input);
}



///
unittest {
    // couples of input and expected result
    immutable text = [[
        "some text\n" ~
        "more text",

        "some text\n" ~
        "more text"
    ],
    [
        "// start with comments\n" ~
        "some text // other comment\n" ~
        "more text",

        "\n" ~
        "some text \n" ~
        "more text"
    ],
    [
        "/ almost a comment but text\n" ~
        "some text // an actual comment\n" ~
        "more text",

        "/ almost a comment but text\n" ~
        "some text \n" ~
        "more text"
    ],
    [
        "some text // comment\n" ~
        "more text",

        "some text \n" ~
        "more text"
    ],
    [
        "some text # comment\n" ~
        "more text",

        "some text \n" ~
        "more text"
    ],
    [
        "some text /* inlined comment */ more text",

        "some text  more text"
    ],
    [
        "some text /* comment with // inlined\n" ~
        "over 2 lines */ more text",

        "some text  more text"
    ],
    [
        "some text // comment with /* inlined\n" ~
        "more text",

        "some text \n" ~
        "more text"
    ],
    [
        "some text # comment with */ inlined\n" ~
        "more text",

        "some text \n" ~
        "more text"
    ],
    [
        "some text /* multiline comment\n" ~
        "still in comment\n" ~
        "again comment */ more text",

        "some text  more text"
    ]];

    foreach (t; text) {
        import std.algorithm : equal;
        import std.format : format;
        import std.conv : to;

        string input = t[0];
        string result = t[0].stripComments().to!string;
        string expected = t[1];

        assert(equal(expected, result), format(
            "stripComments test failed.\ninput:\n%s\nresult:\n%s\nexpected:\n%s\n",
            input, result, expected
        ));
    }

    foreach (t; text) {
        import std.algorithm : equal;
        import std.string : lineSplitter;
        import std.format : format;

        string [] input;
        string [] result;
        string [] expected;
        foreach (s; t[0].lineSplitter) input ~= s;
        foreach (s; t[0].lineSplitter.stripComments) result ~= s;
        foreach (s; t[1].lineSplitter) expected ~= s;

        assert(equal(expected, result), format(
            "lineSplitter.stripComments test failed.\ninput:\n%s\nresult:\n%s\nexpected:\n%s\n",
            input, result, expected
        ));
    }
}

/// Transforms the given input range by replacing lines that have @include directive
/// with the content of the included file. Filenames are looked for in the list
/// of directories includeDirs.
/// input must be a range of lines (as given e.g. by std.string.lineSplitter)
auto handleIncludeDirs(R)(R input, in string[] includeDirs=[])
if (isInputRange!R && isSomeString!(ElementType!R))
{
    return HandleIncludeDirsResult!R(input, includeDirs);
}

private struct HandleIncludeDirsResult(R)
{
    IncludeHandler!(ElementType!R) hdler;

    this (R input, in string[] includeDirs)
    {
        hdler = makeIncludeHandler(input, includeDirs);
    }

    @property bool empty()
    {
        return hdler.empty;
    }
    @property auto front()
    {
        return hdler.front;
    }
    void popFront()
    {
        hdler.popFront();
    }
}

private auto makeIncludeHandler(R) (R input, in string[] includeDirs)
{
    alias StringT = typeof(input.front);
    return cast(IncludeHandler!StringT)(new IncludeHandlerImpl!R(input, includeDirs));
}

private interface IncludeHandler(StringT)
{
    @property bool empty();
    @property IncludeHandler!StringT save();
    @property StringT front();
    void popFront();
}

private class IncludeHandlerImpl(R) : IncludeHandler!(ElementType!R)
{
    alias StringT = ElementType!R;

    R _input;
    const(string[]) _includeDirs;
    IncludeHandler!StringT _dir;
    bool _fstCheck;


    this (R input, in string[] includeDirs)
    {
        _input = input;
        _includeDirs = includeDirs;
    }

    private this (R input, in string[] includeDirs, IncludeHandler!StringT dir, bool fstCheck)
    {
        _input = input;
        _includeDirs = includeDirs;
        _dir = dir;
        _fstCheck = fstCheck;
    }

    @property IncludeHandler!StringT save()
    {
        static if (isForwardRange!R)
        {
            return new IncludeHandlerImpl!R(_input.save, _includeDirs, _dir ? _dir.save : null, _fstCheck);
        }
        else
        {
            assert(false, "not implementable with input of type "~R.stringof);
        }
    }

    @property bool empty()
    {
        if (_dir) {
            return _dir.empty && _input.empty;
        }
        else {
            return _input.empty;
        }
    }

    @property StringT front()
    {
        if (!_fstCheck) check();
        if (_dir && !_dir.empty) return _dir.front;
        return _input.front;
    }

    void popFront()
    {
        if (_dir && !_dir.empty)
        {
            _dir.popFront();
            if (_dir.empty) {
                _dir = null;
                if (!_input.empty)
                {
                    _input.popFront();
                    check();
                }
            }
        }
        else {
            _input.popFront();
            check();
        }
    }

    private void check()
    {
        import std.algorithm : canFind;
        import std.path : chainPath;
        import std.file : exists, read;
        import std.string : lineSplitter;
        import std.regex : ctRegex, matchFirst;
        import std.conv : to;

        _fstCheck = true;

        if (_input.empty) return;
        auto line = _input.front;
        assert(!line.canFind('\n'), "handleIncludeDirs must be passed a line range");

        auto re = ctRegex!("^\\s*@include\\s*\"(.*)\"\\s*$");
        auto m = matchFirst(line, re);

        if(m) {
            assert(m.length >= 2);
            auto fname = m[1];

            assert(!_dir);
            foreach(d; _includeDirs)
            {
                auto fpath = chainPath(d, fname).to!string;
                if (exists(fpath)) {
                    // TODO: handle escaped chars in fname
                    auto content = cast(StringT)read(fpath);
                    _dir = makeIncludeHandler(content.lineSplitter, _includeDirs);
                }
            }
            if(!_dir) {
                throw new Exception("unresolved include directive: "~fname);
            }
        }
    }
}

///
unittest
{
    import std.file : write, readText, remove;

    scope(exit) {
        remove("test.cfg");
    }
    write("test.cfg", "name=12");

    // couples of input and expected result
    auto text = [[
        "foo=10\nbar:30",
        "foo=10\nbar:30"
    ],
    [
        "@include \"test.cfg\"",
        "name=12"
    ],
    [
        "foo=10\n  @include \"test.cfg\" \nbar:30",
        "foo=10\nname=12\nbar:30"
    ],
    [
        "foo=10\n@include\"test.cfg\"\nbar:30",
        "foo=10\nname=12\nbar:30"
    ],
    [
        "foo=10\n@include      \"test.cfg\"\nbar:30",
        "foo=10\nname=12\nbar:30"
    ]];


    foreach (t; text) {
        import std.algorithm : equal;
        import std.string : lineSplitter;
        import std.format : format;

        string [] input;
        string [] result;
        string [] expected;
        foreach (s; t[0].lineSplitter) input ~= s;
        foreach (s; t[0].lineSplitter.handleIncludeDirs(["."])) result ~= s;
        foreach (s; t[1].lineSplitter) expected ~= s;

        assert(equal(expected, result),
            format("lineSplitter.handleIncludeDirs test failed.\ninput:\n%s\nresult:\n%s\nexpected:\n%s\n",
                input, result, expected));
    }

}