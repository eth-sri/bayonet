import std.conv, std.algorithm, std.range, std.array;
import lexer, expression, declaration, util;

import std.typecons: Q=Tuple,q=tuple;

class Builder{
	class Variable{
		string name;
		string type;
		Program.Expression init_;
		this(string name,string type,Program.Expression init_=null){
			this.name=name;
			this.type=type;
			this.init_=init_;
		}
		string toPSI(){
			return name~": "~type;
		}
		string toPSIInit()in{assert(!!init_);}body{
			return name~" = "~init_.toPSI()~";";
		}
	}
	class Program{
		string name;
		this(string name){
			this.name=name;
		}
		void addState(string name,Program.Expression init_=null){
			state~=new Variable(name,name=="pkt"?"Packet":"ℝ",init_);
			stateSet[name]=[];
		}
		class Label{// TODO: get rid of this?
			int id=-1;
			Statement stm;
			void here()in{assert(id==-1);}body{
				id=cast(int)stms.length;
				stms~=[stm];
			}
			string toPSI()in{assert(id!=-1);}body{
				return "__state = "~to!string(id)~";\n";
			}
		}
		Label getLabel(){
			return new Label();
		}
		static abstract class Statement{
			abstract string toPSI();
		}
		static abstract class Expression{
			abstract string toPSI();
		}
		Statement assign(Expression name, Expression rhs){
			static class AssignStm: Statement{
				bool pkt=false;
				Expression var;
				Expression rhs;
				this(Expression var,Expression rhs){ this.var=var; this.rhs=rhs; }
				override string toPSI(){
					return var.toPSI()~" = "~rhs.toPSI()~";\n";
				}
			}
			return new AssignStm(name,rhs);
		}
		Statement define(Expression name, Expression rhs){
			static class DefineStm: Statement{
				Expression var;
				Expression rhs;
				this(Expression var,Expression rhs){ this.var=var; this.rhs=rhs; }
				override string toPSI(){
					return var.toPSI()~" := "~rhs.toPSI()~";\n";
				}
			}
			return new DefineStm(name,rhs);
		}
		Expression read(string name){
			static class Read: Expression{
				string name;
				this(string name){ this.name=name; }
				override string toPSI(){
					if(name == "pkt") return "Q_in.data[0][0]";
					if(name == "port") return "Q_in.data[0][1]";
					return name;
				}
			}
			return new Read(name);
		}
		Expression literal(int value){
			static class Literal: Expression{
				int value;
				this(int value){ this.value=value; }
				override string toPSI(){ return to!string(value); }
			}
			return new Literal(value);
		}
		Expression binary(Expression e1,Expression e2,string op){
			class BinaryExp: Expression{
				Expression e1,e2;
				string op;
				this(Expression e1,Expression e2, string op){
					this.e1=e1; this.e2=e2; this.op=op;
					if(op=="or") this.op="||";
					if(op=="and") this.op="&&";
				}
				override string toPSI(){
					return "("~e1.toPSI()~op~e2.toPSI()~")";
				}
			}
			return new BinaryExp(e1,e2,op);
		}
		Expression field(Expression e,string f){
			class FieldExp: Expression{
				Expression e;
				string f;
				this(Expression e,string f){ this.e=e; this.f=f; }
				override string toPSI(){
					return e.toPSI()~"."~f;
				}
			}
			return new FieldExp(e,f);
		}
		Expression call(Expression f,Expression[] args){
			static class Call: Expression{
				Expression f;
				Expression[] args;
				this(Expression f,Expression[] args){
					this.f=f;
					this.args=args;
				}
				override string toPSI(){
					return text(f.toPSI(),"(",args.map!(a=>a.toPSI()).join(","),")");
				}
			}
			return new Call(f,args);
		}
		Expression ite(Expression cond,Expression then,Expression othw){
			static class IteExp: Expression{
				Expression cond;
				Expression then,othw;
				this(Expression cond,Expression then,Expression othw){
					this.cond=cond;
					this.then=then; this.othw=othw;
				}
				override string toPSI(){
					return text("if ",cond.toPSI(),"{ ",then.toPSI()," } else { ",othw.toPSI()," }");
				}
			}
			return new IteExp(cond,then,othw);
		}
		Statement compound(Statement[] stms){
			static class CompoundStm: Statement{
				Statement[] stms;
				this(Statement[] stms){
					this.stms=stms;
				}
				override string toPSI(){
					return stms.map!(s=>s.toPSI()).join();
				}
			}
			return new CompoundStm(stms);
		}
		Statement skip(){
			static class Skip: Statement{
				override string toPSI(){ return ""; }
			}
			return new Skip();
		}
		Statement new_(){
			static class NewStm: Statement{
				override string toPSI(){
					return "Q_in.pushFront((Packet(),0));\n";
				}
			}
			return new NewStm();
		}
		Statement dup(){
			static class DupStm: Statement{
				override string toPSI(){
					return "Q_in.dupFront();\n";
				}
			}
			return new DupStm();
		}
		Statement drop(){
			static class DropStm: Statement{
				override string toPSI(){
					return "Q_in.popFront();\n";
				}
			}
			return new DropStm();
		}
		Statement fwd(Expression port){
			static class FwdStm: Statement{
				Expression port;
				this(Expression port){ this.port=port; }
				override string toPSI(){
					return text("if(Q_in.size()>0){ Q_out.pushBack((Q_in.takeFront()[0],",port.toPSI(),")); }\n");
				}
			}
			return new FwdStm(port);
		}
		Statement getIf(Expression cnd,Statement then,Statement othw){
			static class IteStm: Statement{
				Expression cnd;
				Statement then,othw;
				this(Expression cnd,Statement then,Statement othw){
					this.cnd=cnd; this.then=then; this.othw=othw;
				}
				override string toPSI(){
					return text("if ",cnd.toPSI(),"{\n",
					            indent(then.toPSI()),"}",
					            othw?text(" else {\n",
					                      indent(othw.toPSI()),
					                      "}\n"):"\n");
				}
			}
			return new IteStm(cnd,then,othw);
		}
		Statement observe(Expression e){
			static class ObserveStm: Statement{
				Expression e;
				this(Expression e){ this.e=e; }
				override string toPSI(){
					return text("observe(",e.toPSI(),");\n");
				}
			}
			return new ObserveStm(e);
		}
		Statement assert_(Expression e){
			static class AssertStm: Statement{
				Expression e;
				this(Expression e){ this.e=e; }
				override string toPSI(){
					return text("assert(",e.toPSI(),");\n");
				}
			}
			return new AssertStm(e);
		}
		void addStatement(Label loc,Statement stm){
			stms~=stm;
		}
		string toPSI(){
			string r="def __run(){\n";
			foreach(i,s;stms){
				if(!s){ continue; }
				r~=indent(s.toPSI());
			}
			r~="}";
			r="dat __"~name~"_ty{\n"~indent(
				"Q_in: Queue, Q_out: Queue;\n"~
				state.map!(a=>a.toPSI()).join(", ")~(state.length?";\n":"")~
				"def __"~name~"_ty(){\n"~indent(
					"Q_in = Queue();\n"~
					"Q_out = Queue();\n"~
					state.filter!(a=>!!a.init_).map!(a=>a.toPSIInit()~"\n").join
				)~"}\n"~
				r~"\n"
			)~"}";
			return r;
		}
	private:
		Variable[] state;
		void[0][string] stateSet;
		Statement[] stms;
	}
	Program addProgram(string name){
		auto r=new Program(name);
		programs~=r;
		return r;
	}
	void addPacketField(string name){
		packetFields~=new Variable(name,"ℝ");
	}
	void addNode(string name)in{assert(name !in nodeId);}body{
		nodeId[name]=cast(int)nodes.length;
		nodes~=name;
	}
	void addProgram(string node,string name)in{assert(node in nodeId);}body{
		foreach(i,p;programs) if(p.name==name){ // TODO: replace linear lookup
			nodeProg[nodeId[node]]=cast(int)i;
			return;
		}
		assert(0);
	}
	void addLink(InterfaceDecl a,InterfaceDecl b){
		auto x=q(a.node.name,a.port), y=q(b.node.name,b.port);
		links[x[0]][x[1]]=y;
		links[y[0]][y[1]]=x;
	}
	void addParam(ParameterDecl p){
		params~=p;
	}
	void addScheduler(FunctionDef scheduler){
		this.scheduler=scheduler;
	}
	void addPostObserve(Expression decl){
		postObserves~=decl;
	}
	void addNumSteps(NumStepsDecl numSteps){
		this.num_steps = numSteps.num_steps;
	}
	void addQueueCapacity(QueueCapacityDecl capacity){
		this.capacity = capacity.capacity;
	}
	void addQuery(QueryDecl query){
		queries~=query.query;
	}
	private string formatData(){
		assert(!!scheduler,"scheduler missing"); // TODO: catch in semantic
		BinaryExp!(Tok!"@").toStringImpl=(Expression e1,Expression e2)=>
			text("(",iota(nodes.length).map!(k=>text(k+1==nodes.length?"":text("if ",e2," == ",k)," { __",nodes[k],".",e1," }")).join(" else "),")");
		auto nonterminal = nodes.map!(n=>text("__",n,".Q_in.size() || __",n,".Q_out.size()")).join(" || ");
		string r="dat __D{\n"~indent(
			iota(nodes.length).map!(k=>"__"~nodes[k]~" : __"~programs[nodeProg[cast(int)k]].name~"_ty").join(", ")~(nodes.length?";\n":"")~
			(scheduler.state?
			 scheduler.state.vars.map!(v=>text(v.name,": ℝ")).join(", ")~(scheduler.state.vars.length?";\n":"")
			 :"")~
			"def __D(){\n"~indent(
				iota(nodes.length).map!(k=>"__"~nodes[k]~" = __"~programs[nodeProg[cast(int)k]].name~"_ty()").join(", ")~(nodes.length?";\n":"")~
				(scheduler.state?
				 scheduler.state.vars.map!(v=>text(v.name," = ",v.init?v.init.toString():"0",";\n")).join
			 :"")
			)~"}\n"~
			"def scheduler()"~scheduler.body_.toString()~"\n"~
			"def __step(){\n"~indent(
				"if "~nonterminal~" {\n"~indent(
					"(action,node) := scheduler();\n"~
					"if action {\n"~indent(// FwdQ
						iota(nodes.length)
						.map!(k=>
						      "if node == "~text(k)~" && __"~nodes[k]~".Q_out.size() {\n"~indent((){
								      string r="(pkt,port) := __"~nodes[k]~".Q_out.takeFront();\n";
								      foreach(p;links[nodes[k]].keys.sort()){
									      auto nnode=links[nodes[k]][p];
									      r~="if port == "~text(p)~" {\n"~indent(
										      "__"~nnode[0]~".Q_in.pushBack((pkt, "~text(nnode[1])~"));\n"
									      )~"}\n";
								      }
								      return r;
							      }())~"}\n").join
					)~"} else {\n"~indent(//RunSw
						iota(nodes.length).map!(k=>
						                        "if node == "~text(k)~" && __"~nodes[k]~".Q_in.size() {\n"~indent(
							                        "__"~nodes[k]~".__run();\n"
						                        )~"}\n").join
					)~"}\n"
				)~"}\n"
			)~"}\n"
		)~"}\n";
		return r;
	}
	private bool nodeHasVar(int node,Expression var){
		auto id=cast(Identifier)var;
		assert(!!id);
		auto prg=programs[nodeProg[cast(int)node]];
		return !!(id.name in prg.stateSet);
	}
	private string formatQueries(){
		BinaryExp!(Tok!"@").toStringImpl=(Expression e1,Expression e2)=>
			text("(",iota(nodes.length).filter!(k=>nodeHasVar(cast(int)k,e1)).map!(k=>text("if ",e2," == ",k," { __d.__",nodes[k],".",e1," }")).join(" else ")," else { assert(0) })");
		string formatQuery(Expression q){
			if(auto ce=cast(CallExp)q){
				if(auto id=cast(Identifier)ce.e){
					if(id.name=="expectation") return text("Expectation(",ce.args.map!(x=>x.toString).join(", "),")");
					if(id.name=="probability") return text("Expectation((",ce.args.map!(x=>x.toString).join(", "),") !=0)");
				}
			}
			return q.toString();
		}
		return iota(queries.length).map!(i=>text("q",lowNum(i+1)," := ",formatQuery(queries[i]),";\n")).join~"return ("~iota(queries.length).map!(i=>"q"~lowNum(i+1)).join(", ")~");\n";
	}
	string toPSI(){
		auto pfields=packetFields.map!(a=>a.toPSI()).join(", ");
		auto nodedef="k := "~text(nodes.length)~", "~iota(nodes.length).map!(k=>text(nodes[k]," := ",k)).join(", ")~(nodes.length?";\n":"");
		auto paramdef=params.map!(p=>p.name.toString()~" := "~(p.init_?p.init_.toString():"?"~p.name.toString())).join(", ")~(params.length?";\n":"");
		auto packetdef="dat Packet{\n"~indent(
			(packetFields.length?pfields~";\n":"")~
			"def Packet("~/+pfields~+/"){\n"~indent(
				/+packetFields.map!(a=>a.name~" = "~a.name~";\n").join()+/ // TODO
				packetFields.map!(a=>a.name~" = 0;\n").join()
			)~"}\n"
		)~"}\n";
		auto nonterminal = nodes.map!(n=>text("__d.__",n,".Q_in.size() || __d.__",n,".Q_out.size()")).join(" || ");
		auto data=formatData(), queries=formatQueries();
		auto pObserves = postObserves.map!(po=>text("observe(",po.toString(),");\n")).join;
		auto mainfun=
			data~
			"def main(){\n"~indent(
			"__d := __D();\n"~
			(nodes.length?
			 "__d.__"~nodes[0]~".Q_in.pushBack((Packet(),0));\n"
			 ~"__d.__"~nodes[0]~".__run();\n":"")~
			"repeat num_steps {\n"~indent(
				"__d.__step();\n"
			)~"}\n"~
			pObserves~
			"assert(!("~nonterminal~"));\n"~
			queries
			)~"}\n";
		auto queuedef="dat Queue{\n"~indent(
			"data: (Packet × ℝ)[];\n"~
			"def Queue(){\n"~indent(
				"data = ([]:(Packet × ℝ)[]);\n"
			)~"}\n"~
			"def pushFront(x: Packet × ℝ){\n"~indent(
				(capacity?"if size() >= "~capacity.toString()~" { return; }\n":"")~
				"data=[x]~data;\n"
			)~"}\n"~
			"def pushBack(x: Packet × ℝ){\n"~indent(
				(capacity?"if size() >= "~capacity.toString()~" { return; }\n":"")~
				"data=data~[x];\n"
			)~"}\n"~
			"def takeFront(){\n"~indent(
				"r:=front();\n"~
				"popFront();\n"~
				"return r;\n"
			)~"}\n"~
			"def takeBack(){\n"~indent(
				"r:=data[size()-1];\n"~
				"data=data[0..size()-1];\n"~
				"return r;\n"
			)~"}\n"~
			"def size(){\n"~indent(
				"return data.length;\n"
			)~"}\n"~
			"def front(){\n"~indent(
				"return data[0];\n"
			)~"}\n"~
			"def dupFront(){\n"~indent(
				"pushFront(front());\n"
			)~"}\n"~
			"def popFront(){\n"~indent(
				"data=data[1..size()];\n"
			)~"}\n"
		)~"}\n";
		return "num_steps := "~num_steps.toString()~";\n"~queuedef~nodedef~paramdef~packetdef~programs.map!(a=>a.toPSI()~"\n").join~"RunSw:=0, FwdQ:=1;\n"~mainfun;
	}
private:
	Variable[] packetFields;
	Program[] programs;
	string[] nodes;
	ParameterDecl[] params;
	int[string] nodeId;
	int[int] nodeProg;
	Q!(string,int)[int][string] links;
	FunctionDef scheduler;
	Expression[] queries;
	Expression num_steps;
	Expression capacity;
	Expression[] postObserves;
}

string translate(Expression[] exprs, Builder bld){
	Expression[][typeof(typeid(Object))] byTid;
	foreach(expr;exprs){
		assert(cast(Declaration)expr && expr.sstate==SemState.completed,text(expr));
		byTid[typeid(expr)]~=expr;
	}
	auto all(T)(){ return cast(T[])byTid.get(typeid(T),[]); }
	auto topology=all!TopologyDecl[0];
	foreach(n;topology.nodes) bld.addNode(n.name.name);
	foreach(l;topology.links) bld.addLink(l.a,l.b);
	auto params=all!ParametersDecl.length?all!ParametersDecl[0]:null;
	if(params) foreach(prm;params.params) bld.addParam(prm);
	auto pfld=all!PacketFieldsDecl[0];
	foreach(f;pfld.fields) bld.addPacketField(f.name.name);
	auto pdcl=all!ProgramsDecl[0];
	bld.addNumSteps(all!NumStepsDecl[0]);
	if(all!QueueCapacityDecl.length) bld.addQueueCapacity(all!QueueCapacityDecl[0]);
	foreach(q;all!QueryDecl) bld.addQuery(q);
	void translateFun(FunctionDef fdef){
		auto prg=bld.addProgram(fdef.name.name);
		/+foreach(prm;fdef.params)
			prg.addState(prm.name);+/
		Builder.Program.Expression translateExpression(Expression exp){
			if(auto be=cast(ABinaryExp)exp){
				auto e1=translateExpression(be.e1);
				auto e2=translateExpression(be.e2);
				return prg.binary(e1,e2,be.operator);
			}else if(auto id=cast(Identifier)exp){
				return prg.read(id.name);
			}else if(auto lit=cast(LiteralExp)exp){
				assert(lit.lit.type==Tok!"0",text("TODO: ",lit));
				return prg.literal(to!int(lit.lit.str));
			}else if(auto ce=cast(CallExp)exp){
				return prg.call(translateExpression(ce.e),ce.args.map!(a=>translateExpression(a)).array);
			}else if(auto ite=cast(IteExp)exp){
				auto cond=translateExpression(ite.cond);
				Expression getIt(Expression e){
					auto ce=cast(CompoundExp)e;
					assert(ce&&ce.s.length==1);
					return ce.s[0];
				}
				return prg.ite(cond,translateExpression(getIt(ite.then)),translateExpression(getIt(ite.othw)));
			}else if(auto be=cast(BuiltInExp)exp){
				if(be.which==Tok!"FwdQ") return prg.literal(0);
				if(be.which==Tok!"RunSw") return prg.literal(1);
			}else if(auto fe=cast(FieldExp)exp){
				return prg.field(translateExpression(fe.e),fe.f.name);
			}
			assert(0,text("TODO: ",exp));
		}
		if(fdef.state)
			foreach(sd;fdef.state.vars)
				prg.addState(sd.name.name,sd.init_?translateExpression(sd.init_):null);
		alias Statement=Builder.Program.Statement;
		alias Label=Builder.Program.Label;
		Statement translateStatement(Expression stm,Label nloc,Label loc)in{assert(!!nloc);}body{
			Builder.Program.Statement tstm=null;
			if(auto be=cast(ABinaryExp)stm){
				if(cast(BinaryExp!(Tok!"="))be){
					auto e=translateExpression(be.e2);
					tstm=prg.assign(translateExpression(be.e1),e);
				}else if(cast(BinaryExp!(Tok!":="))be){
					auto e=translateExpression(be.e2);
					tstm=prg.define(translateExpression(be.e1),e);
				}else assert(0,text(stm));
			}else if(auto ite=cast(IteExp)stm){
				auto cnd=translateExpression(ite.cond);
				auto join=nloc;
				auto tloc=prg.getLabel();
				tloc.here();
				auto then=translateStatement(ite.then,join,tloc);
				auto oloc=prg.getLabel();
				oloc.here();
				auto othw=ite.othw?translateStatement(ite.othw,join,oloc):null;
				tstm=prg.getIf(cnd,then,othw);
			}else if(auto obs=cast(ObserveExp)stm){
				auto cnd=translateExpression(obs.e);
				tstm=prg.observe(cnd);
			}else if(auto ass=cast(AssertExp)stm){
				auto cnd=translateExpression(ass.e);
				tstm=prg.assert_(cnd);
			}else if(auto be=cast(BuiltInExp)stm){
				if(be.which==Tok!"new") tstm=prg.new_();
				if(be.which==Tok!"dup") tstm=prg.dup();
				if(be.which==Tok!"drop") tstm=prg.drop();
			}else if(auto ce=cast(CallExp)stm){
				auto be=cast(BuiltInExp)ce.e;
				assert(be&&be.which==Tok!"fwd");
				assert(ce.args.length==1);
				tstm=prg.fwd(translateExpression(ce.args[0]));
			}else if(auto ce=cast(CompoundExp)stm){
				auto cloc=loc;
				if(ce.s.length){
					Statement[] stms;
					foreach(i,s;ce.s){
						auto cnloc=i+1==ce.s.length?nloc:prg.getLabel();
						stms~=translateStatement(s,cnloc,cloc);
						if(i+1!=ce.s.length) cnloc.here();
						cloc=cnloc;
					}
					tstm=prg.compound(stms);
				}else tstm=prg.skip();
			}
			//assert(tstm && nloc,text("TODO: ",stm));
			static class TODOStatement: Builder.Program.Statement{
				Expression stm;
				this(Expression stm){ this.stm=stm; }
				override string toPSI(){
					return "/+ TODO: "~stm.toString()~"+/\n";
				}
			}
			if(!tstm) tstm=new TODOStatement(stm);
			// tstm.next=nloc;
			return tstm;
		}
		auto init=prg.getLabel();
		init.here();
		prg.addStatement(init,translateStatement(fdef.body_,init,init));
	}
	foreach(fdef;all!FunctionDef){
		if(fdef.name.name=="scheduler") bld.addScheduler(fdef);
		else translateFun(fdef);
	}
	foreach(m;pdcl.mappings) bld.addProgram(m.node.name,m.prg.name);
	foreach(p;all!PostObserveDecl) bld.addPostObserve(p.e);
	return bld.toPSI();
}
