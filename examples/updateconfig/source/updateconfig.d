module updateconfig;

import std.stdio;
import config;

int main()
{
	auto conf = Config.readString(import("example.cfg"));

	auto inventory = conf.root.child("inventory");
	if (!inventory)
	{
		inventory = conf.root.add("inventory", Type.Group);
	}

	auto movies = inventory.child("movies").asList;
	if (!movies)
	{
		movies = inventory.asGroup.add!(Type.List)("movies");
	}

	auto movie = movies.add!(Type.Group);
	movie.addScalar("title", "Buckaroo Banzai");
	movie.addScalar("media", "DVD");
	movie.addScalar("price", 12.99);
	movie.addScalar("qty", 20);

	conf.writeTo(File("updated.cfg", "w").lockingTextWriter());

	return 0;
}
