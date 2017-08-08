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
	// semantic information
	FunctionDef prg;
}
class InterfaceDecl: Declaration{
	Identifier node;
	int port;
	this(Identifier node,int port){
		super(null);
		this.node=node;
		this.port=port;
	}
	override @property string kind(){ return "interface"; }
	override string toString(){ return "("~node.toString()~", pt"~to!string(port)~")"; }
}
class LinkDecl: Declaration{
	InterfaceDecl a,b;
	this(Identifier name,InterfaceDecl a,InterfaceDecl b){ super(name); this.a=a; this.b=b; }
	override @property string kind(){ return "link"; }
	override string toString(){ return (name?name.toString~": ":"link: ")~a.toString()~" <-> "~b.toString(); }
}

class TopologyDecl: Declaration{
	NodeDecl[] nodes;
	LinkDecl[] links;
	this(NodeDecl[] nodes,LinkDecl[] links){ super(null); this.nodes = nodes; this.links=links; }
	override string toString(){ return "topology { nodes { "~nodes.map!(to!string).join(", ")~" } links{ "~links.map!(to!string).join(", ")~" } } "; }
}

class ParameterDecl: Declaration{
	Expression init_;
	this(Identifier name, Expression init_){ super(name); this.init_=init_; }
	override @property string kind(){ return "parameter"; }
	override string toString(){ assert(!!name); return name.toString()~(init_?"("~init_.toString()~")":""); }
}

class ParametersDecl: Declaration{
	ParameterDecl[] params;
	this(ParameterDecl[] params){ super(null); this.params = params; }
	override @property string kind(){ return "parameters"; }
	override string toString(){ return "parameters { "~params.map!(to!string).join(", ")~" }"; }
}

class PacketFieldsDecl: Declaration{
	VarDecl[] fields;
	this(VarDecl[] fields){ super(null); this.fields=fields; }
	override @property string kind(){ return "packet fields"; }
	override string toString(){ return "packet_fields { "~fields.map!(x=>x.name.to!string).join(", ")~" }"; }
}

class ProgramsDecl: Declaration{
	ProgramMappingDecl[] mappings;
	this(ProgramMappingDecl[] mappings){ super(null); this.mappings = mappings; }
	override @property string kind(){ return "programs"; }
	override string toString(){ return "programs { "~mappings.map!(to!string).join(", ")~" }"; }
}

class ProgramMappingDecl: Declaration{
	Identifier node;
	Identifier prg;
	StateDecl inits;
	this(Identifier node,Identifier prg,StateDecl inits){ super(null); this.node=node; this.prg=prg; this.inits=inits;}
	override @property string kind(){ return "program mapping"; }
	override string toString(){ return node.toString()~" -> "~prg.toString()~(inits?"with { "~inits.bodyToString()~" }":""); }
}

class QueryDecl: Declaration{
	Expression query;
	this(Expression query){ super(null); this.query=query; }
	override @property string kind(){ return "query declaration"; }
	override string toString(){ return "query "~query.toString(); }
}

class PostObserveDecl: Declaration{
	Expression e;
	this(Expression e){ super(null); this.e=e; }
	override @property string kind(){ return "post_observe declaration"; }
	override string toString(){ return "post_observe "~e.toString(); }
}

class NumStepsDecl: Declaration{
	Expression num_steps;
	this(Expression num_steps){ super(null); this.num_steps=num_steps; }
	override @property string kind(){ return "num_steps declaration"; }
	override string toString(){ return "num_steps "~num_steps.toString(); }
}

class QueueCapacityDecl: Declaration{
	Expression capacity; // TODO: allow setting capacity on per node.
	this(Expression capacity){ super(null); this.capacity=capacity; }
	override @property string kind(){ return "queue_capacity declaration"; }
	override string toString(){ return "queue_capacity "~capacity.toString(); }
}

class CompoundDecl: Expression{
	Expression[] s;
	this(Expression[] ss){s=ss;}

	override string toString(){return "{\n"~indent(join(map!(a=>a.toString()~(a.isCompound()?"":";"))(s),"\n"))~"\n}";}
	override bool isCompound(){ return true; }

	// semantic information
	AggregateScope ascope_;
}

class StateVarDecl: VarDecl{
	Expression init_;
	this(Identifier name,Expression init_){ super(name); this.init_=init_; }
	override @property string kind(){ return "state variable"; }
	override string toString(){ return name.toString()~(init_?"("~init_.toString()~")":""); }
}

class StateDecl: Declaration{
	StateVarDecl[] vars;
	this(StateVarDecl[] vars){ super(null); this.vars=vars; }
	override @property string kind(){ return "state declaration"; }
	final string bodyToString(){
		return vars.map!(to!string).join(", ");
	}
	override string toString(){ return "state "~bodyToString(); }
}

class FunctionDef: Declaration{
	Identifier[] params;
	StateDecl state;
	Expression rret;
	CompoundExp body_;
	this(Identifier name,Identifier[] params, StateDecl state, Expression rret, CompoundExp body_){
		super(name); this.state=state; this.params=params; this.rret=rret; this.body_=body_;
	}
	override string toString(){ return "def "~(name?name.toString():"")~"("~join(map!(to!string)(params),", ")~")"~body_.toString(); }

	override bool isCompound(){ return true; }

	// semantic information
	FunctionScope fscope_;
}

class VarDecl: Declaration{
	this(Identifier name){
		super(name);
	}
}
