import std.file;
import std.stdio;
import std.datetime;
import std.array;
import std.algorithm;
import dlexer;
import core.memory;

enum RUN_COUNT = 100;

void bench(ubyte[] f)
{
	StopWatch sw = StopWatch(AutoStart.no);
    float[RUN_COUNT] timings;
	foreach (i; 0 .. RUN_COUNT)
	{
		GC.disable();
		int count;
		sw.start();
		auto l = DLexer!(ubyte[])(f);
		foreach (token; l)
		{
			count++;
		}
		sw.stop();
		timings[i] = sw.peek().to!("msecs", float)();
		sw.reset();
		GC.enable();
	}
	auto s = reduce!((a, b) => a + b)(timings);
    writeln(s / RUN_COUNT);
}

void main(string[] args)
{
	ubyte[] f = cast(ubyte[]) read(args[1]);
	bench(f);
//	foreach (token; DLexer!(typeof(f))(f))
//		writeln(token);
}