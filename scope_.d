import std.format;
import std.typecons: Tuple, tuple;
import std.conv: text;
import lexer, expression, declaration, error;

abstract class Scope{
	abstract @property ErrorHandler handler();
	abstract @property PacketFieldScope packetFieldScope();
	bool insert(Declaration decl)in{assert(!decl.scope_);}body{
		auto d=symtabLookup(decl.name);
		if(d){
			redefinitionError(decl, d);
			decl.sstate=SemState.error;
			return false;
		}
		symtab[decl.name.ptr]=decl;
		decl.scope_=this;
		return true;
	}
	void redefinitionError(Declaration decl, Declaration prev) in{
		assert(decl);
		assert(decl.name.ptr is prev.name.ptr);
	}body{
		error(format("redefinition of '%s'",decl.name), decl.name.loc);
		note("previous definition was here",prev.name.loc);
	}

	protected final Declaration symtabLookup(Identifier ident){
		return symtab.get(ident.ptr, null);
	}
	Declaration lookup(Identifier ident){
		return lookupHere(ident);
	}
	final Declaration lookupHere(Identifier ident){
		auto r = symtabLookup(ident);
		return r;
	}
	
	bool isNestedIn(Scope rhs){ return rhs is this; }

	void error(lazy string err, Location loc){handler.error(err,loc);}
	void note(lazy string err, Location loc){handler.note(err,loc);}

	abstract FunctionDef getFunction();
private:
	Declaration[const(char)*] symtab;
}

class TopScope: Scope{
	private ErrorHandler handler_;
	override @property ErrorHandler handler(){ return handler_; }
	PacketFieldScope pkt;
	override @property PacketFieldScope packetFieldScope(){
		return pkt;
	}
	this(ErrorHandler handler){
		this.handler_=handler;
		this.pkt=new PacketFieldScope(this);
	}
	private TopologyDecl topology;

	private NodeDecl[const(char)*] nodes;
	private Tuple!(NodeDecl,int,Location)[Tuple!(NodeDecl,int)] graph;
	NodeDecl lookupNode(Identifier name){
		if(name.name.ptr in nodes) return nodes[name.name.ptr];
		error("undefined node '"~name.name~"'",name.loc);
		return null;
	}
	final bool setTopology(TopologyDecl topology)in{assert(!this.topology);}body{
		this.topology=topology;
		bool err=false;
		foreach(n;topology.nodes){
			if(n.name.name.ptr in nodes){
				error(text("redeclaration of node ",n.name),n.loc);
				note("previous declaration was here",nodes[n.name.name.ptr].loc);
				err=true;
			}
			nodes[n.name.name.ptr]=n;
			insert(n);
		}
		foreach(l;topology.links){
			auto a=lookupNode(l.a.node),b=lookupNode(l.b.node);
			if(a&&b){
				void addDirected(InterfaceDecl a,InterfaceDecl b){
					auto tpa=tuple(lookupNode(a.node),a.port);
					auto tpb=tuple(lookupNode(b.node),b.port,a.loc);
					if(tpa in graph){
						error(text("multiple links connected to interface ",a),a.loc);
						note("previous connection was declared here",graph[tpa][2]);
						err=true;
					}
					graph[tpa]=tpb;
				}
				addDirected(l.a,l.b);
				addDirected(l.b,l.a);
			}else err=true;
		}
		return !err;
	}
	override FunctionDef getFunction(){ return null; }
}

class PacketFieldScope: Scope{
	TopScope top;
	override @property ErrorHandler handler(){ return top.handler; }
	override @property PacketFieldScope packetFieldScope(){ return this; }
	override FunctionDef getFunction(){ return null; }
	this(TopScope top){
		this.top=top;
	}
}

class NestedScope: Scope{
	Scope parent;
	override @property ErrorHandler handler(){ return parent.handler; }
	override @property PacketFieldScope packetFieldScope(){ return parent.packetFieldScope; }
	this(Scope parent){ this.parent=parent; }
	override Declaration lookup(Identifier ident){
		if(auto decl=lookupHere(ident)) return decl;
		return parent.lookup(ident);
	}

	override bool isNestedIn(Scope rhs){ return rhs is this || parent.isNestedIn(rhs); }
	
	override FunctionDef getFunction(){ return parent.getFunction(); }
}

class FunctionScope: NestedScope{
	FunctionDef fd;
	this(Scope parent,FunctionDef fd){
		super(parent);
		this.fd=fd;
	}

	override FunctionDef getFunction(){ return fd; }
}
class BlockScope: NestedScope{
	this(Scope parent){ super(parent); }
}
class AggregateScope: NestedScope{
	this(Scope parent){ super(parent); }
}
