import std.algorithm;
import scope_,lexer,expression,declaration;

Expression[] semantic(Source src,Expression[] exprs,Scope sc){
	auto lineZero=src.lineZero;
	Expression[][typeof(typeid(Object))] byTid;
	foreach(expr;exprs){
		// byTid[typeid(expr)]++;// bad error message, report dmd bug
		byTid[typeid(expr)]~=expr;
		if(!cast(Declaration)expr){
			sc.error("toplevel entities must be declarations",expr.loc);
		}
	}
	auto all(T)(){ return byTid.get(typeid(T),[]); }
	auto secondLoc(typeof(typeid(Object)) tid){
		auto exprs=byTid.get(tid,[]);
		return exprs.length?exprs[min(exprs.length-1,1)].loc:lineZero;
	}
	// TODO: provide help with syntax for missing declarations
	if(all!TopologyDecl.length!=1) sc.error("there should be exactly one topology declaration",secondLoc(typeid(TopologyDecl)));
	if(all!ParametersDecl.length>1) sc.error("there can be at most one parameters declaration",all!ParametersDecl[1].loc);
	if(all!PacketFieldsDecl.length!=1) sc.error("there should be exactly one declaration of packet fields",secondLoc(typeid(PacketFieldsDecl)));
	if(all!ProgramsDecl.length!=1) sc.error("there should be exactly one declaration of programs to run on the nodes",secondLoc(typeid(ProgramsDecl)));

	void doSemantic(T)(){
		foreach(ref expr;exprs){
			auto t=cast(T)expr;
			if(!t) continue;
			expr=semantic(t,sc);
		}
	}
	doSemantic!TopologyDecl;
	doSemantic!ParametersDecl;
	doSemantic!PacketFieldsDecl;
	doSemantic!FunctionDef;
	return exprs;
}	

Expression semantic(Expression expr,Scope sc){
	if(auto tpl=cast(TopologyDecl)expr){
		if(auto tsc=cast(TopScope)sc)
			if(!tsc.setTopology(tpl))
				tpl.sstate=SemState.error;
		return tpl;
	}
	return expr;
}
