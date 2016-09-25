module config.util;

import std.range : isForwardRange, isRandomAccessRange, hasLength;
import std.traits : isSomeString;

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
        import std.range : empty;

        immutable balance = findAmong!pred(seq, choices);
        immutable pos1 = seq.length - balance.length;
        immutable pos2 = balance.empty ? pos1 : pos1 + 1;
        return makeResult(seq[0 .. pos1], seq[pos1 .. pos2], seq[pos2 .. $]);
    }
    else
    {
        import std.range : takeExactly, takeOne, empty, front, popFront, save;
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
