import std.algorithm;
import scope_,lexer,expression,declaration;
import util;

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
	if(all!NumStepsDecl.length!=1) sc.error("there should be exactly one declaration of the number of steps to run",secondLoc(typeid(NumStepsDecl)));
	if(all!QueryDecl.length<1) sc.error("there should be at least one query declaration",lineZero);
	if(all!QueueCapacityDecl.length>1) sc.error("there should be at most one queue capacity declaration",lineZero);
	
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
	doSemantic!ProgramsDecl;
	doSemantic!NumStepsDecl;
	doSemantic!QueueCapacityDecl;
	doSemantic!QueryDecl;
	doSemantic!PostObserveDecl;
	return exprs;
}	

Expression semantic(Expression expr,Scope sc){
	static void propErr(Expression e1,Expression e2){
		if(e1.sstate==SemState.error)
			e2.sstate=SemState.error;
	}
	static Expression finish(Expression e){
		if(e.sstate!=SemState.error)
			e.sstate=SemState.completed;
		return e;
	}
	if(auto tpl=cast(TopologyDecl)expr){
		if(auto tsc=cast(TopScope)sc)
			if(!tsc.setTopology(tpl))
				tpl.sstate=SemState.error;
		return finish(tpl);
	}
	if(auto prm=cast(ParametersDecl)expr){
		foreach(ref param;prm.params){
			param=cast(ParameterDecl)semantic(param,sc);
			assert(!!param);
			propErr(param,prm);
		}
		return finish(prm);
	}
	if(auto prm=cast(ParameterDecl)expr){
		if(!sc.insert(prm))
			prm.sstate=SemState.error;
		return finish(prm);
	}
	if(auto pfld=cast(PacketFieldsDecl)expr){
		foreach(ref field;pfld.fields){
			field=cast(VarDecl)semantic(field,sc.packetFieldScope());
			assert(!!field);
			propErr(field,pfld);
		}
		return finish(pfld);
	}
	if(auto pd=cast(ProgramsDecl)expr){
		foreach(mp;pd.mappings){
			if(auto decl=sc.lookup(mp.node)){
				if(auto node=cast(NodeDecl)decl){
					if(auto decl2=sc.lookup(mp.prg)){
						if(auto prg=cast(FunctionDef)decl2){
							if(node.prg){
								sc.error("program for node '"~node.name.name~"' already declared",mp.loc);
							}else node.prg=prg;
						}else{
							sc.error("not a program",mp.node.loc);
							sc.note("declared here",decl.loc);
							pd.sstate=SemState.error;
						}
					}else{
						sc.error("undefined identifier",mp.prg.loc);
						pd.sstate=SemState.error;
					}
				}else{
					sc.error("not a node in the network",mp.node.loc);
					sc.note("declared here",decl.loc);
					pd.sstate=SemState.error;
				}
			}else{
				sc.error("undefined identifier",mp.node.loc);
				pd.sstate=SemState.error;
			}
		}
		// TODO: ensure each node has a program:
		/+if(pd.mappings.length!=tpl.nodes.length){
			sc.error("there should be one program declaration for each node",pd.loc);
			pd.sstate=SemState.error;
		}+/
		// TODO: allow a wildcard specifier
		return finish(pd);
	}
	if(auto nsd=cast(NumStepsDecl)expr){
		if(auto lit=cast(LiteralExp)nsd.num_steps){
			if(lit.lit.type==Tok!"0"){
				try{
					import std.conv:to;
					auto ns=to!int(lit.lit.str);
					if(ns>=0) return finish(nsd);
				}catch(Exception){}
			}
		}
		sc.error("number of steps should be non-negative integer literal",nsd.num_steps.loc);
		nsd.sstate=SemState.error;
		return nsd;
	}
	if(auto qcd=cast(QueueCapacityDecl)expr){
		if(auto lit=cast(LiteralExp)qcd.capacity){
			if(lit.lit.type==Tok!"0"){
				try{
					import std.conv:to;
					auto qc=to!int(lit.lit.str);
					if(qc>=0) return finish(qcd);
				}catch(Exception){}
			}
		}
		sc.error("queue capacity should be non-negative integer literal",qcd.capacity.loc);
		qcd.sstate=SemState.error;
		return qcd;
	}
	if(auto qd=cast(QueryDecl)expr){
		return finish(qd);
	}
	if(auto pd=cast(PostObserveDecl)expr){
		return finish(pd);
	}
	if(auto vd=cast(VarDecl)expr){
		if(!sc.insert(vd))
			vd.sstate=SemState.error;
		return finish(vd);
	}
	if(auto fd=cast(FunctionDef)expr){
		if(fd.name.name=="scheduler") return finish(fd);
		if(!sc.insert(fd)) fd.sstate=SemState.error;
		if(!fd.fscope_) fd.fscope_=new FunctionScope(sc,fd);
		if(fd.params.length){
			if(fd.params.length!=2||fd.params[0].name!="pkt"||fd.params[1].name!="port"){
				sc.error("function parameters must be () or (pkt,port)",fd.loc);
				fd.sstate=SemState.error;
			}
		}
		if(fd.state) foreach(ref vd;fd.state.vars)
			vd=cast(StateVarDecl)semantic(vd,fd.fscope_);
		foreach(ref statement;fd.body_.s){
			statement=semantic(statement,fd.fscope_);
			propErr(statement,fd);
		}
		return finish(fd);
	}
	if(auto be=cast(BuiltInExp)expr){
		return finish(be);
	}
	if(auto ae=cast(BinaryExp!(Tok!"="))expr){
		ae.e1=semantic(ae.e1,sc);
		ae.e2=semantic(ae.e2,sc);
		propErr(ae.e1,ae);
		propErr(ae.e2,ae);
		auto id=cast(Identifier)ae.e1;
		if(!id&&!cast(FieldExp)ae.e1){
			sc.error("can only assign variables or packet fields",ae.loc);
			ae.sstate=SemState.error;
		}
		if(id && (id.name=="pkt"||id.name=="port")){
			sc.error("cannot reassign parameters",ae.loc);
			ae.sstate=SemState.error;
		}
		return finish(ae);
	}
	if(auto de=cast(BinaryExp!(Tok!":="))expr){
		de.e2=semantic(de.e2,sc);
		propErr(de.e2,de);
		auto id=cast(Identifier)de.e1;
		if(!id){
			sc.error("left hand side of definition must be identifier",de.loc);
			de.sstate=SemState.error;
			return de;
		}
		auto vd=new VarDecl(id);
		if(!sc.insert(vd))
			de.sstate=SemState.error;
		return finish(de);
	}
	if(auto be=cast(ABinaryExp)expr){
		be.e1=semantic(be.e1,sc);
		be.e2=semantic(be.e2,sc);
		propErr(be.e1,be);
		propErr(be.e2,be);
		return finish(be);
	}
	if(auto fld=cast(FieldExp)expr){
		fld.e=semantic(fld.e,sc);
		propErr(fld.e,fld);
		auto id=cast(Identifier)fld.e;
		auto fd=sc.getFunction();
		if((!id||id.name!="pkt")&&(!fd||!fd.params.length)){
			sc.error("can only access fields of 'pkt'",fld.loc);
			fld.sstate=SemState.error;
			return fld;
		}
		if(!sc.packetFieldScope().lookup(fld.f)){
			fld.sstate=SemState.error;
		}
		return finish(fld);
	}
	if(auto id=cast(Identifier)expr){
		if(!sc.lookup(id)){
			if(auto fd=sc.getFunction()){
				if(fd.params.length==2 && id.name=="port" || id.name=="pkt")
					return finish(id);
			}
			sc.error("undefined identifier",id.loc);
			id.sstate=SemState.error;
		}
		return finish(id);
	}
	if(auto lit=cast(LiteralExp)expr)
		return finish(lit);
	if(auto ce=cast(CallExp)expr){
		//ce.e=semantic(ce.e,sc);
		//propErr(ce.e,ce);
		foreach(ref arg;ce.args){
			arg=semantic(arg,sc);
			propErr(arg,ce);
		}
		if(ce.sstate==SemState.error) return ce;
		auto be=cast(BuiltInExp)ce.e;
		if((!be||be.which!=Tok!"fwd")&&!isBuiltInDistribution(cast(Identifier)ce.e)){
			sc.error("can only call 'fwd' or sampling expression",ce.loc);
			ce.sstate=SemState.error;
			return ce;
		}
		if(be&&be.which==Tok!"fwd"&&ce.args.length!=1){
			sc.error("expected a single argument to 'fwd'",ce.loc);
			ce.sstate=SemState.error;
			return ce;
		}
		return finish(ce);
	}
	if(auto ite=cast(IteExp)expr){
		ite.cond=semantic(ite.cond,sc);
		ite.then=cast(CompoundExp)semantic(ite.then,sc);
		assert(!!ite.then);
		if(ite.othw){
			ite.othw=cast(CompoundExp)semantic(ite.othw,sc);
			assert(ite.othw);
		}
		propErr(ite.cond,ite);
		propErr(ite.then,ite);
		if(ite.othw) propErr(ite.othw,ite);
		return finish(ite);
	}
	if(auto obs=cast(ObserveExp)expr){
		obs.e=semantic(obs.e,sc);
		propErr(obs.e,obs);
		return finish(obs);
	}
	if(auto ass=cast(AssertExp)expr){
		ass.e=semantic(ass.e,sc);
		propErr(ass.e,ass);
		return finish(ass);
	}
	if(auto cmp=cast(CompoundExp)expr){
		foreach(ref s;cmp.s){
			s=semantic(s,sc);
		}
		return cmp;
	}
	Expression handleBinary(ref Expression e1,ref Expression e2,Expression e){
		e1=semantic(e1,sc);
		e2=semantic(e2,sc);
		propErr(e1,e), propErr(e2,e);
		return finish(e);
	}
	if(auto be=cast(BinaryExp!(Tok!"=="))expr){
		return handleBinary(be.e1,be.e2,be);
	}
	sc.error("unsupported",expr.loc);
	expr.sstate=SemState.error;
	return expr;
}

bool isBuiltInDistribution(Identifier id){
	if(!id) return false;
	return true; // TODO
}
