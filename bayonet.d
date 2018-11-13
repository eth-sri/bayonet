import std.stdio, std.path, std.array, std.string, std.algorithm;
import file=std.file;
import lexer, parser, expression, declaration, error, util;
import scope_, semantic_;

enum OutputType { PSI, PRISM, PRISM_DET }

string getActualPath(string path){
	// TODO: search path
	auto ext = path.extension;
	if(ext=="") path = path.setExtension("bayonet");
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


int run(string path, OutputType ot){
	path = getActualPath(path);
	auto ext = path.extension;
	if(ext != ".bayonet"){
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
	program=semantic(src,program,new TopScope(err));
	//writeln(program);
	if(!err.nerrors){
		if(ot==OutputType.PSI){
			import translate_;
			writeln(translate(program,new Builder()));
		}else if(ot==OutputType.PRISM){
			import translate_prism;
			writeln(translate(program,new Builder()));
		}else if(ot==OutputType.PRISM_DET){
			import translate_prism_deterministic;
			writeln(translate(program,new Builder()));
		}else{
			assert(0);
		}
	}
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
	OutputType ot = OutputType.PSI;
	bool otSet = false;
	foreach(x;args){
		if(x=="--psi" || x=="--prism" || x=="--prism-det"){
			if(otSet){
				stderr.writeln("error: output type already set");
				return 1;
			}
			if(x=="--psi")
				ot = OutputType.PSI;
			else if(x=="--prism")
				ot = OutputType.PRISM;
		  else if(x=="--prism-det")
				ot = OutputType.PRISM_DET;
			else
				assert(0);
			otSet = true;
			continue;
		}
		if(auto r=run(x,ot)) return r;
	}
	return 0;
}
