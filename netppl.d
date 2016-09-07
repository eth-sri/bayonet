import std.stdio, std.path, std.array, std.string, std.algorithm;
import file=std.file;
import lexer, parser, expression, declaration, error, util;

string getActualPath(string path){
	// TODO: search path
	auto ext = path.extension;
	if(ext=="") path = path.setExtension("prb");
	//return file.getcwd().canFind("/test")?path:"test/"~path;
	return path;
}

string readCode(File f){
	// TODO: use memory-mapped file with 4 padding zero bytes
	auto app=mallocAppender!(char[])();
	foreach(r;f.byChunk(1024)){app.put(cast(char[])r);}
	app.put("\0\0\0\0"); // insert 4 padding zero bytes
	return cast(string)app.data;	
}
string readCode(string path){ return readCode(File(path)); }


int run(string path){
	path = getActualPath(path);
	auto ext = path.extension;
	if(ext != ".netppl"){
		stderr.writeln(path~": unrecognized extension: "~ext);
		return 1;
	}
	string code;
	try code=readCode(path);
	catch(Exception){
		if(!file.exists(path)) stderr.writeln(path ~ ": no such file");
		else stderr.writeln(path ~ ": error reading file");
		return 1;
	}
	auto src=new Source(path, code);
	auto err=new FormattingErrorHandler();
	auto program=parseFile(src,err);
	writeln(program);
	return !!err.nerrors;
}

int main(string[] args){
	//import core.memory; GC.disable();
	version(TEST) test();
	if(args.length<2){
		stderr.writeln("error: no input files");
		return 1;
	}
	args.popFront();
	args.sort!((a,b)=>a.startsWith("--")>b.startsWith("--"));
	foreach(x;args){
		if(auto r=run(x)) return r;
	}
	return 0;
}
