module readconfig;

import std.stdio;
import config;

void main()
{
	auto conf = Config.readString(import("example.cfg"));

	auto name = conf.lookUpValue!string("name");
	if (name.isNull) stderr.writeln("could not get store name");
	else writeln("Store name: ", name, "\n");

	if (auto books = conf.lookUp("inventory.books"))
	{
		writeln("Books:");
		writefln("%-30s  %-30s   %-6s  %s", "TITLE", "AUTHOR", "PRICE", "QTY");
		foreach (book; books.children)
		{
			auto title = book.lookUpValue!string("title");
			auto author = book.lookUpValue!string("author");
			auto price = book.lookUpValue!float("price");
			auto qty = book.lookUpValue!int("qty");
			if (!title.isNull && !author.isNull && !price.isNull && !qty.isNull)
			{
				writefln("%-30s  %-30s  $%6.2f  %3d", title, author, price, qty);
			}
		}
		writeln();
	}

	if (auto movies = conf.lookUp("inventory.movies"))
	{
		writeln("Movies:");
		writefln("%-30s  %-10s   %-6s  %s", "TITLE", "MEDIA", "PRICE", "QTY");
		foreach (movie; movies.children)
		{
			auto title = movie.lookUpValue!string("title");
			auto media = movie.lookUpValue!string("media");
			auto price = movie.lookUpValue!float("price");
			auto qty = movie.lookUpValue!int("qty");
			if (!title.isNull && !media.isNull && !price.isNull && !qty.isNull)
			{
				writefln("%-30s  %-10s  $%6.2f  %3d", title, media, price, qty);
			}
		}
		writeln();
	}
}
