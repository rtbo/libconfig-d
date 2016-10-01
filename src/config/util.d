module config.util;

import std.range : isForwardRange, ElementType;
import std.traits : isSomeString, isSomeChar, Unqual;

auto findSplitAmong(alias pred="a == b", R1, R2)(R1 seq, R2 choices)
if (isForwardRange!R1 && isForwardRange!R2)
{
    import std.range.primitives;

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
if (isForwardRange!R && isSomeChar!(ElementType!R))
{
    import std.range.primitives;

    struct Result
    {
        R _input;
        ElementType!R[] _lookAhead;

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
            if (_lookAhead.length) {
                return _lookAhead[0];
            }
            else {
                return _input.front;
            }
        }

        void popFront()
        {
            if (_lookAhead.length) {
                _lookAhead = _lookAhead[1 .. $];
                return;
            }

            _input.popFront();
            if (_input.empty) return;

            if (_input.front == '#') popUntilEol();

            else if (_input.front == '/')
            {
                _input.popFront();
                if (_input.empty) return;

                if (_input.front == '/') popUntilEol();
                else if (_input.front == '*') popUntilEndBlock();

                else _lookAhead ~= _input.front;
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

    return Result(input, []);
}



/// strip libconfig comments on a line by line basis
auto stripComments(R)(R input)
if (isForwardRange!R && isSomeString!(ElementType!R))
{
    import std.range.primitives;
    import std.stdio;

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

        @property auto save()
        {
            return Result(_input.save, _buf.dup, _inBlock);
        }

        @property bool empty()
        {
            return _buf.empty && _input.empty;
        }

        @property auto front()
        {
            return _buf.empty ? _input.front : _buf;
        }

        void popFront()
        {
            _buf = [];
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

            if (_inBlock) {
                _input.popFront();
                if (_input.empty) throw new Exception("comment block not closed");
                else fetch();
            }
        }
    }

    return Result(input);
}




unittest {
    import std.algorithm : equal;
    import std.stdio : writeln;

    // couples of input and expected result
    immutable text = [[
        "some text\n"
        "more text",

        "some text\n"
        "more text"
    ],
    [
        "some text // comment\n"
        "more text",

        "some text \n"
        "more text"
    ],
    [
        "some text # comment\n"
        "more text",

        "some text \n"
        "more text"
    ],
    [
        "some text /* inlined comment */ more text",

        "some text  more text"
    ],
    [
        "some text /* comment with // inlined\n"
        "over 2 lines */ more text",

        "some text  more text"
    ],
    [
        "some text // comment with /* inlined\n"
        "more text",

        "some text \n"
        "more text"
    ],
    [
        "some text # comment with */ inlined\n"
        "more text",

        "some text \n"
        "more text"
    ],
    [
        "some text /* multiline comment\n"
        "still in comment\n"
        "again comment */ more text",

        "some text  more text"
    ]];

    foreach (t; text) {
        import std.format : format;
        import std.conv : to;

        string input = t[0];
        string result = t[0].stripComments().to!string;
        string expected = t[1];

        assert(equal(expected, result),
            format("stripComments test failed.\ninput:\n%s\nresult:\n%s\nexpected:\n%s\n",
                input, result, expected));
    }

    foreach (t; text) {
        import std.string : lineSplitter;
        import std.format : format;

        string [] input;
        string [] result;
        string [] expected;
        foreach (s; t[0].lineSplitter) input ~= s;
        foreach (s; t[0].lineSplitter.stripComments) result ~= s;
        foreach (s; t[1].lineSplitter) expected ~= s;

        assert(equal(expected, result),
            format("lineSplitter.stripComments test failed.\ninput:\n%s\nresult:\n%s\nexpected:\n%s\n",
                input, result, expected));
    }
}