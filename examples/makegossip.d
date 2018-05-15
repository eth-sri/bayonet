import std.stdio, std.conv, std.string, std.range, std.algorithm, std.array;


void main(){
	int k=readln().strip.to!int;
	int[] ports=repeat(0,k).array;
	writeln("num_steps ",5*(k-1),";");
	writeln("topology{");
	writeln("nodes {\n",iota(k).map!(i=>text("S",i)).join(",\n"),"\n}");
	writeln("links {");
	foreach(i;0..k){
		foreach(j;i+1..k){
			writeln("(S",i,",pt",++ports[i],") <-> (S",j,",pt",++ports[j],"),");
		}
	}
	writeln("}");
	writeln("}");
	writeln("packet_fields{ }");
	writeln("programs {");
	foreach(i;0..k) writeln("S",i," -> ",i==0?"first":"node",",");
	writeln("}");
	writeln("query expectation(0");
	foreach(i;0..k) writeln("+ infected@S",i);
	writeln(");");
	writefln(r"
def first(pkt,port) state infected(0){
	if infected == 0 {
		infected = 1;
		new;
		fwd(uniformInt(1,%s));
	}else{ drop; }
}

def node(pkt,port) state infected(0){
	if infected == 0{
		infected = 1;
		dup;
		fwd(uniformInt(1,%s));
		fwd(uniformInt(1,%s));
	}else{ drop; }
}

def scheduler(){
	actions := ([]: (R x R)[]);
	for i in [0..k){
		if (Q_in@i).size() > 0 { actions ~= [(RunSw,i)]; }
		if (Q_out@i).size() > 0 { actions ~= [(FwdQ,i)]; }
	}
	return actions[uniformInt(0,actions.length-1)];
}
",k-1,k-1,k-1);
}
