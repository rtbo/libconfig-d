module config.test;

version(unittest):

import config.config;

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

void parseErrAndCompare(string input, string expectedMsg)
{
    import std.exception : collectException;
    import std.stdio : writeln;

    writeln(input);

    auto e = collectException(Config.readString(input, ["."]));
    assert(e !is null);
    writeln(e.msg);
}


unittest
{
    import std.file : write, remove;

    scope(exit) remove("more.cfg");
    write("more.cfg", import("more.cfg"));

    foreach (tf; testFiles)
    {
        parseAndCompare(tf[0], tf[1]);
    }

    parseFileAndCompare(testFiles[2][0], testFiles[2][1]);
}

unittest
{
    foreach (tf; testErrFiles)
    {
        // this do not pass at the moment
        // as cannot retrieve errors from Pegged
        //parseErrAndCompare(tf[0], tf[1]);
    }
}

unittest
{
    immutable confStr = "someint = 5";
    const conf = Config.readString(confStr);
    immutable si = conf.lookUpValue!int("someint");
    immutable sl = conf.lookUpValue!long("someint");
    assert(!si.isNull);
    assert(si.get == 5);
    assert(!sl.isNull);
    assert(sl.get == 5);
}

unittest
{
    import std.exception : assertThrown;
    import std.format : format;

    immutable val = long(2)^^33;
    immutable confStr = format("someint = %s", val);
    const conf = Config.readString(confStr);
    assertThrown(conf.lookUpValue!int("someint"));
    immutable sl = conf.lookUpValue!long("someint");
    assert(!sl.isNull);
    assert(sl.get == val);
}

unittest
{
    import std.exception : assertThrown;
    import std.format : format;

    immutable val = -long(2)^^33;
    immutable confStr = format("someint = %s", val);
    const conf = Config.readString(confStr);
    assertThrown(conf.lookUpValue!int("someint"));
    immutable sl = conf.lookUpValue!long("someint");
    assert(!sl.isNull);
    assert(sl.get == val);
}

unittest
{
    import std.format : format;

    immutable val = 2^^31 - 1;
    immutable confStr = format("someint = %s", val);
    const conf = Config.readString(confStr);
    immutable si = conf.lookUpValue!int("someint");
    immutable sl = conf.lookUpValue!long("someint");
    assert(!si.isNull);
    assert(si.get == val);
    assert(!sl.isNull);
    assert(sl.get == val);
}

unittest
{
    import std.exception : assertThrown;
    import std.format : format;

    immutable val = long(2)^^31;
    immutable confStr = format("someint = %s", val);
    const conf = Config.readString(confStr);
    assertThrown(conf.lookUpValue!int("someint"));
    immutable sui = conf.lookUpValue!uint("someint");
    immutable sl = conf.lookUpValue!long("someint");
    assert(!sui.isNull);
    assert(sui.get == val);
    assert(!sl.isNull);
    assert(sl.get == val);
}

unittest
{
    import std.format : format;

    immutable val = 52;
    immutable confStr = format("someint = %s", val);
    const conf = Config.readString(confStr);
    immutable sf = conf.lookUpValue!float("someint");
    assert(!sf.isNull);
    assert(sf.get == val);
}

