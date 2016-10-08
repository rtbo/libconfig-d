module buildconfig;

import std.stdio;
import config;

void main()
{
	auto conf = new Config;

	auto address = conf.root.add!(Type.Group)("address");
	address.addScalar("street", "1 Woz Way");
	address.addScalar("city", "San Jose");
	address.addScalar("state", "CA");
	address.addScalar("zip", 95110);

	auto numbers = conf.root.add!(Type.Array)("numbers");
	foreach(i; 0..10)
	{
		numbers.addScalar(10*i);
	}

	conf.writeTo(File("built.cfg", "w").lockingTextWriter);
}
