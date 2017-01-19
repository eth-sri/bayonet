import std.conv, std.algorithm, std.range, std.array;
import lexer, expression, declaration, util;

import std.typecons: Q=Tuple,q=tuple;

enum queuedef=q"QUEUE
dat Queue{
    data: (Packet × ℝ)[];
    def Queue(){
        data = ([]:(Packet × ℝ)[]);
    }
    def pushFront(x: Packet × ℝ){
        data=[x]~data;
    }
    def pushBack(x: Packet × ℝ){
        data=data~[x];
    }
    def takeFront(){
        r:=front();
        popFront();
        return r;
    }
    def takeBack(){
        r:=data[size()-1];
        data=data[0..size()-1];
        return r;
    }
    def size(){
        return data.length;
    }
    def front(){
        return data[0];
    }
    def popFront(){
        data=data[1..size()];
    }
}
QUEUE";

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
		}
		class Label{
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
			Label next;
			string toPSI(){
				return next.toPSI();
			}
		}
		static abstract class Expression{
			abstract string toPSI();
		}
		Statement assign(string name, Expression rhs){
			static class AssignStm: Statement{
				bool pkt=false;
				string var;
				Expression rhs;
				this(string var,Expression rhs){ this.var=var; this.rhs=rhs; }
				override string toPSI(){
					return var~"="~rhs.toPSI()~";\n"~super.toPSI();
				}
			}
			return new AssignStm(name,rhs);
		}
		Expression read(string name){
			static class Read: Expression{
				string name;
				this(string name){ this.name=name; }
				override string toPSI(){ return name; }
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
				this(Expression e1,Expression e2, string op){
					this.e1=e1; this.e2=e2;
				}
				override string toPSI(){
					return e1.toPSI()~op~e2.toPSI();
				}
			}
			return new BinaryExp(e1,e2,op);
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
		Statement skip(){
			static class Skip: Statement{}
			return new Skip();
		}
		Statement new_(){
			static class NewStm: Statement{
				override string toPSI(){
					return "Q_in.pushFront((Packet(),0));\n"~super.toPSI();
				}
			}
			return new NewStm();
		}
		Statement dup(){
			static class DupStm: Statement{
				override string toPSI(){
					return "Q_in.dupFront();\n"~super.toPSI();
				}
			}
			return new DupStm();
		}
		Statement drop(){
			static class DropStm: Statement{
				override string toPSI(){
					return "Q_in.popFront();"~super.toPSI();
				}
			}
			return new DropStm();
		}
		Statement fwd(Expression port){
			static class FwdStm: Statement{
				Expression port;
				this(Expression port){ this.port=port; }
				override string toPSI(){
					return text("Q_out.pushBack((Q_in.takeFront()[0],",port.toPSI(),"));\n"~super.toPSI());
				}
			}
			return new FwdStm(port);
		}
		Statement getIf(Expression cnd,Label then,Label othw){
			static class IteStm: Statement{
				Expression cnd;
				Label then,othw;
				this(Expression cnd,Label then,Label othw){
					this.cnd=cnd; this.then=then; this.othw=othw;
				}
				override string toPSI(){
					return text("if ",cnd.toPSI(),"{\n",indent(then.toPSI()),"}else{\n",indent(othw.toPSI()),"}\n");
				}
			}
			return new IteStm(cnd,then,othw);
		}
		void addStatement(Label loc,Statement stm){
			assert(!loc.stm);
			loc.stm=stm;
			if(loc.id!=-1){
				assert(stms.length>loc.id && stms[loc.id] is null);
				stms[loc.id]=stm;
			}
		}
		string toPSI(){
			string r="def __run(){\n    ";
			foreach(i,s;stms){
				if(!s){ r~=text("// missing: ",i); continue; }
				r~=text(i==0?"":"else ","if this.__state==",i,"{\n",indent(indent(s.toPSI))~"    }");
			}
			r~="\n}";
			r="dat __"~name~"_ty{\n"~indent(
				"__state: ℝ, Q_in: Queue, Q_out: Queue;\n"~
				state.map!(a=>a.toPSI()).join(", ")~";\n"~
				"def __"~name~"_ty(){\n"~indent(
					"__state = 0;\n"~
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
	void addScheduler(FunctionDef scheduler){
		this.scheduler=scheduler;
	}
	private string formatData(){
		string r="dat __D{\n"~indent(
			iota(nodes.length).map!(k=>"__"~nodes[k]~" : __"~programs[nodeProg[cast(int)k]].name~"_ty").join(", ")~";\n"~
			(scheduler.state?
			 scheduler.state.vars.map!(v=>text(v.name,": ℝ")).join(", ")~";\n"
			 :"")~
			"def __D(){\n"~indent(
				iota(nodes.length).map!(k=>"__"~nodes[k]~" = __"~programs[nodeProg[cast(int)k]].name~"_ty()").join(", ")~";\n"~
				(scheduler.state?
				 scheduler.state.vars.map!(v=>text(v.name," = ",v.init?v.init.toString():"0",";\n")).join
			 :"")
			)~"}\n"~
			"def scheduler()"~scheduler.body_.toString()~"\n"
		)~"}\n";
		return r;
	}
	string toPSI(){
		BinaryExp!(Tok!"@").toStringImpl=(Expression e1,Expression e2)=>
			text("(",iota(nodes.length).map!(k=>text(k+1==nodes.length?"":text("if ",e2," == ",k)," { __",nodes[k],".",e1," }")).join(" else "),")");
		auto pfields=packetFields.map!(a=>a.toPSI()).join(", ");
		auto nodedef="k := "~text(nodes.length)~", "~iota(nodes.length).map!(k=>text(nodes[k]," := ",k)).join(", ")~";\n";
		auto packetdef="dat Packet{\n"~indent(
			pfields~";\n"~
			"def Packet("~/+pfields~+/"){\n"~indent(
				/+packetFields.map!(a=>a.name~" = "~a.name~";\n").join()+/ // TODO
				packetFields.map!(a=>a.name~" = 0;\n").join()
			)~"}\n"
		)~"}\n";
		auto mainfun=
			formatData()~
			"def main(){\n"~indent(
			"__d := __D();\n"~
			"for i in [0..num_iter) {\n"~indent(
				"if "~nodes.map!(n=>text("__d.__",n,".Q_in.size()")).join(" || ")~" {\n"~indent(
					"(node,action) := __d.scheduler();\n"~
					"if action {\n"~indent(// FwdQ
						iota(nodes.length)
						.map!(k=>
						      "if node == "~text(k)~" && __d.__"~nodes[k]~".Q_out.size() {\n"~indent((){
								      string r="(pkt,port) := __d.__"~nodes[k]~".Q_out.takeFront();\n";
								      foreach(p;links[nodes[k]].keys.sort()){
									      auto nnode=links[nodes[k]][p];
									      r~="if port == "~text(p)~" {\n"~indent(
										      "__d.__"~nnode[0]~".Q_in.pushBack((pkt, "~text(nnode[1])~"));\n"
									      )~"}\n";
								      }
								      return r;
							      }())~"}\n").join
					)~"} else {\n"~indent(//RunSw
						iota(nodes.length).map!(k=>
						                        "if node == "~text(k)~" && __d.__"~nodes[k]~".Q_in.size() {\n"~indent(
							                        "(__d.__"~nodes[k]~".pkt,__d.__"~nodes[k]~".port) = __d.__"~nodes[k]~".Q_in.front();\n"~
							                        "__d.__"~nodes[k]~".__run();\n"
						                        )~"}\n").join
					)~"}\n"
				)~"}\n"
			)~"}\n"
		)~"}\n";
		return "num_iter := 10;\n"~queuedef~nodedef~packetdef~programs.map!(a=>a.toPSI()~"\n").join~"RunSw:=0, FwdQ:=1;\n"~mainfun;
;
	}
private:
	Variable[] packetFields;
	Program[] programs;
	string[] nodes;
	int[string] nodeId;
	int[int] nodeProg;
	Q!(string,int)[int][string] links;
	FunctionDef scheduler;
}

string translate(Expression[] exprs, Builder bld){
	Expression[][typeof(typeid(Object))] byTid;
	foreach(expr;exprs){
		assert(cast(Declaration)expr && expr.sstate==SemState.completed);
		byTid[typeid(expr)]~=expr;
	}
	auto all(T)(){ return cast(T[])byTid.get(typeid(T),[]); }
	auto topology=all!TopologyDecl[0];
	foreach(n;topology.nodes) bld.addNode(n.name.name);
	foreach(l;topology.links) bld.addLink(l.a,l.b);
	auto params=all!ParametersDecl.length?all!ParametersDecl[0]:null;
	auto pfld=all!PacketFieldsDecl[0];
	foreach(f;pfld.fields) bld.addPacketField(f.name.name);
	auto pdcl=all!ProgramsDecl[0];
	void translateFun(FunctionDef fdef){
		auto prg=bld.addProgram(fdef.name.name);
		foreach(prm;fdef.params)
			prg.addState(prm.name);
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
			}
			assert(0,text("TODO: ",exp));
		}
		if(fdef.state)
			foreach(sd;fdef.state.vars)
				prg.addState(sd.name.name,sd.init_?translateExpression(sd.init_):null);
		alias Label=Builder.Program.Label;
		Label translateStatement(Expression stm,Label nloc,Label loc)in{assert(!!nloc);}body{
			Builder.Program.Statement tstm=null;
			if(auto be=cast(ABinaryExp)stm){
				if(cast(BinaryExp!(Tok!"="))be||cast(BinaryExp!(Tok!":="))be){
					auto e=translateExpression(be.e2);
					if(auto id=cast(Identifier)be.e1){
						tstm=prg.assign((cast(Identifier)be.e1).name,e);
					}else{
						tstm=prg.skip(); // TODO!
					}
				}else assert(0,text(stm));
			}else if(auto ite=cast(IteExp)stm){
				auto cnd=translateExpression(ite.cond);
				auto join=nloc;
				auto tloc=prg.getLabel();
				tloc.here();
				auto then=translateStatement(ite.then,join,tloc);
				auto oloc=prg.getLabel();
				oloc.here();
				auto othw=ite.othw?translateStatement(ite.othw,join,oloc):join;
				tstm=prg.getIf(cnd,then,othw);
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
					foreach(i,s;ce.s){
						auto cnloc=i+1==ce.s.length?nloc:prg.getLabel();
						translateStatement(s,cnloc,cloc);
						if(i+1!=ce.s.length) cnloc.here();
						cloc=cnloc;
					}
					return loc;
				}else tstm=prg.skip();
			}
			//assert(tstm && nloc,text("TODO: ",stm));
			static class TODOStatement: Builder.Program.Statement{
				Expression stm;
				this(Expression stm){ this.stm=stm; }
				override string toPSI(){
					return super.toPSI()~"/+ TODO: "~stm.toString()~"+/\n";
				}
			}
			if(!tstm) tstm=new TODOStatement(stm);
			tstm.next=nloc;
			prg.addStatement(loc,tstm);
			return loc;
		}
		auto init=prg.getLabel();
		init.here();
		translateStatement(fdef.body_,init,init);
	}
	foreach(fdef;all!FunctionDef){
		if(fdef.name.name=="scheduler") bld.addScheduler(fdef);
		else translateFun(fdef);
	}
	foreach(m;pdcl.mappings) bld.addProgram(m.node.name,m.prg.name);
	return bld.toPSI();
}
