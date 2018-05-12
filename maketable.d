import std.stdio, std.string, std.algorithm, std.range, std.conv, std.format, std.typecons, std.exception, std.math;
string table;

string reformatResult(string result, bool isApprox){
	if(isApprox){
		enforce(result.startsWith("(") && result.endsWith(")"));
		result=result[1..$-1];
		auto splitted = result.split("*");
		splitted[1] = splitted[1].split("^")[1];
		auto value = to!real(splitted[0])*pow(10.0L,to!real(splitted[1]));
		return format("%.04f",value);
	}else{
		auto splitted = result.split("/");
		assert(1<=splitted.length && splitted.length<=2);
		auto value = to!real(splitted[0])/(splitted.length==2?to!real(splitted[1]):1);
		return format("%.04f",value);
	}
}

auto parseIt(string fname, bool isApprox){
	auto timeStart = "real\t";
	auto resultStart = isApprox?"E[r] = ":"E[q1_] = ";
	try{
		auto exactData = File(fname).byLine;
		string result;
		string time;
		foreach(l;exactData){
			if(l.startsWith(resultStart)){
				auto resultString=l[resultStart.length..$];
				result=reformatResult(resultString.idup, isApprox);
			}
			if(l.startsWith(timeStart)){
				auto timeString=l[timeStart.length..$];
				auto splitted=timeString.strip('s').split("m").map!(to!real);
				auto value=splitted[0]*60+splitted[1];
				time=format(value>5?"%.0fs":"%.1fs",value);
			}
		}
		return tuple(result,time);
	}catch(Exception) return tuple("-","-");
}

void makeRow(string name, string sched, size_t nodes, string fname){
	auto exactResultTime = parseIt("examples/results/"~fname~".txt",false);
	auto exactResult = exactResultTime[0], exactTime = exactResultTime[1];
	auto approxResultTime = parseIt("examples/results-approx/"~fname~".txt",true);
	auto approxResult = approxResultTime[0], approxTime = approxResultTime[1];
	string row=format(`%11s & %s & %2d & $%6s$ & %4s & $%6s$ & %4s\\`,name,sched,nodes,exactResult,exactTime,approxResult,approxTime);
	if(table.length) table~="\n";
	table~=row;
}

void makeSep(){ table~=`\hline`; }

void main(){
	makeRow("Congestion", "uni.", 5, "congestion");
	makeRow("Congestion", "det.", 5, "congestion-deterministic");
	makeRow("Congestion", "uni.", 6, "congestion-large");
	makeRow("Congestion", "det.", 6, "congestion-large-deterministic");
	makeRow("Congestion", "det.", 30, "congestion-largest");
	makeSep();
	makeRow("Reliability", "uni.", 6, "reliability");
	makeRow("Reliability", "det.", 6, "reliability-deterministic");
	makeRow("Reliability", "uni.", 30, "reliability-large-30nodes");
	makeRow("Reliability", "det.", 30, "reliability-deterministic-large-30nodes");
	makeSep();
	makeRow("Gossip", "uni.", 4, "gossip");
	makeRow("Gossip", "det.", 4, "gossip-deterministic");
	makeRow("Gossip", "uni.", 20, "gossip-20");
	makeRow("Gossip", "uni.", 30, "gossip-30");
	writeln(table);
}
