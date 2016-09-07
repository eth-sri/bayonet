import std.array, std.algorithm, std.conv;
import lexer, expression, scope_, util;

class Declaration: Expression{
	Identifier name;
	Scope scope_;
	this(Identifier name){ this.name=name; }
	override @property string kind(){ return "declaration"; }
	override string toString(){ return name?name.toString():""; }
}

class NodeDecl: Declaration{
	this(Identifier name){ super(name); }
	override @property string kind(){ return "node"; }
}
class InterfaceDecl: Declaration{
	Identifier node;
	int port;
	this(Identifier node,int port){
		this.node=node;
		this.port=port;
	}
}
class LinkDecl: Declaration{
	this(Identifier name,InterfaceDecl a,InterfaceDecl b){ super(name); }
	
}


class TopologyDecl: Declaration{
	this(NodeDecl[] nodes,LinkDecl[] decls){ super(null); }
	override string toString(){ return "topology { ... } "; }// TODO
}


class CompoundDecl: Expression{
	Expression[] s;
	this(Expression[] ss){s=ss;}

	override string toString(){return "{\n"~indent(join(map!(a=>a.toString()~(a.isCompound()?"":";"))(s),"\n"))~"\n}";}
	override bool isCompound(){ return true; }

	// semantic information
	AggregateScope ascope_;
}

class FunctionDef: Declaration{
	Identifier[] params;
	Expression rret;
	CompoundExp body_;
	this(Identifier name, Identifier[] params, Expression rret, CompoundExp body_){
		super(name); this.params=params; this.rret=rret; this.body_=body_;
	}
	override string toString(){ return "def "~(name?name.toString():"")~"("~join(map!(to!string)(params),",")~")"~body_.toString(); }

	override bool isCompound(){ return true; }

	// semantic information
	FunctionScope fscope_;
}

