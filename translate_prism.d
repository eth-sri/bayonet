import std.conv, std.algorithm, std.range, std.array;
import lexer, expression, declaration, util;

import std.typecons: Q=Tuple,q=tuple;

class Builder{
	class Variable{
		string name;
		string type;
		string init_;
		this(string name,string type,string init_=""){
			this.name=name;
			this.type=type;
			this.init_=init_;
		}
	}
	class Program{
		alias UpdateList=Q!(string,string)[];
		string name;
		this(string name){
			this.name=name;
		}
		void addState(string name,string init_=""){
			state~=new Variable(name,"int",init_);
			stateSet[name]=[];
		}
		struct TempVarData{
			int count=0;
			Q!(int,int)[] ranges;
			int getNewTemp(int m, int M){
				ranges ~= q(m,M);
				++count;
				return count-1;
			}
		}
		class Label{// TODO: get rid of this?
			int id=-1;
			Statement stm;
			void here()in{assert(id==-1);}body{
				id=cast(int)stms.length;
				stms~=[stm];
			}
			string toPRISM()in{assert(id!=-1);}body{
				return "__state = "~to!string(id)~";\n";
			}
		}
		Label getLabel(){
			return new Label();
		}
		static abstract class Statement{
			abstract void toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName);
		}
		static abstract class Expression{
			abstract string toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName);
		}
		Statement assign(Expression name, Expression rhs){
			static class AssignStm: Statement{
				bool pkt=false;
				Expression var;
				Expression rhs;
				this(Expression var,Expression rhs){ this.var=var; this.rhs=rhs; }
				override void toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName){
					string varStr = var.toPRISM(outStream, tempVars, instCtr, mangName);
					string rhsStr = rhs.toPRISM(outStream, tempVars, instCtr, mangName);
					string output = "[] "~mangName~"pc="~to!string(instCtr)~" & "~rhsStr~">=INTMIN & "~rhsStr~"<=INTMAX";
					UpdateList assignUL;
					assignUL ~= q(varStr,rhsStr);
					assignUL ~= q(mangName~"pc",to!string(instCtr+1));
					output ~= updateListToPRISM(assignUL);
					outStream ~= output;
					++instCtr;
				}
			}
			return new AssignStm(name,rhs);
		}
		Statement define(Expression name, Expression rhs){
			static class DefineStm: Statement{
				Expression var;
				Expression rhs;
				this(Expression var,Expression rhs){ this.var=var; this.rhs=rhs; }
				override void toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName){
					assert(0,text("Define Statement unimplemented for PRISM backend"));
				}
			}
			return new DefineStm(name,rhs);
		}
		Expression read(string name, int varType){
			static class Read: Expression{
				string name;
				int varType;
				this(string name, int varType){
					this.name=name;
					this.varType=varType;
				}
				override string toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName){
					if(name == "pkt") return mangName~"i";
					if(name == "port") return mangName~"ip0";
					if(varType==0)
						return mangName~mangleVar(name);
					else if(varType==1)
						return mangleVar(name);
					else if(varType==2)
						return name;
					else
						assert(0);
				}
			}
			return new Read(name,varType);
		}
		Expression literal(int value){
			static class Literal: Expression{
				int value;
				this(int value){ this.value=value; }
				override string toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName){
					return to!string(value);
				}
			}
			return new Literal(value);
		}
		Expression binary(Expression e1,Expression e2,string op){
			class BinaryExp: Expression{
				Expression e1,e2;
				string op;
				this(Expression e1,Expression e2, string op){
					this.e1=e1; this.e2=e2; this.op=op;
					if(op=="or" || op=="||") this.op="|";
					if(op=="and" || op=="&&") this.op="&";
					if(op=="==") this.op="=";
				}
				override string toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName){
					string s1 = e1.toPRISM(outStream, tempVars, instCtr, mangName);
					string s2 = e2.toPRISM(outStream, tempVars, instCtr, mangName);
					return "("~s1~op~s2~")";
				}
			}
			return new BinaryExp(e1,e2,op);
		}
		Expression field(Expression e,string f){
			class FieldExp: Expression{
				Expression e;
				string f;
				this(Expression e,string f){ this.e=e; this.f=f; }
				override string toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName){
					string pktStr = e.toPRISM(outStream, tempVars, instCtr, mangName);
					return pktStr~mangleVar(f)~"0";
				}
			}
			return new FieldExp(e,f);
		}
		Expression flip(double p){
			static class Flip: Expression{
				double trueProb;
				this(double trueProb){
					this.trueProb=trueProb;
				}
				override string toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName){
					string newTemp = mangName~"t"~to!string(tempVars.getNewTemp(0,1));
					string output = "[] "~mangName~"pc="~to!string(instCtr)~" -> ";
					UpdateList flipUL0, flipUL1;
					flipUL0 ~= q(newTemp,"0");
					flipUL0 ~= q(mangName~"pc",to!string(instCtr+1));
					flipUL1 ~= q(newTemp,"1");
					flipUL1 ~= q(mangName~"pc",to!string(instCtr+1));
					//TODO: rounding errors can occur here, eg. 1/3 -> 0.333 + 0.666 =/= 1.0
					output ~= to!string(1.0-trueProb)~":"~updateListToPRISM_pure(flipUL0)~" + "~to!string(trueProb)~":"~updateListToPRISM_pure(flipUL1)~";\n";
					outStream ~= output;
					++instCtr;
					return newTemp;
				}
			}
			return new Flip(p);
		}
		Expression uniformInt(int m, int M){
			static class UniformInt: Expression{
				int minInt, maxInt;
				this(int minInt, int maxInt){
					assert(minInt<maxInt);
					this.minInt=minInt;
					this.maxInt=maxInt;
				}
				override string toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName){
					string newTemp = mangName~"t"~to!string(tempVars.getNewTemp(minInt,maxInt));
					string output = "[] "~mangName~"pc="~to!string(instCtr)~" -> ";
					string[] possibilities;
					//TODO: rounding errors can occur here, eg. 1-3 -> 0.333 + 0.333 + 0.333 =/= 1.0
					//TODO: handle the edge case where one of the inclusive bounds is the int type minimum/maximum
					for(int i=minInt; i<=maxInt; ++i){
						UpdateList uiUL;
						uiUL ~= q(newTemp,to!string(i));
						uiUL ~= q(mangName~"pc",to!string(instCtr+1));
						possibilities ~= updateListToPRISM_pure(uiUL);
					}
					string uniformProb = to!string(1.0/to!double(maxInt-minInt+1));
					output ~= (possibilities.map!(poss=>uniformProb~":"~poss).join(" + "))~";\n";
					outStream ~= output;
					++instCtr;
					return newTemp;
				}
			}
			return new UniformInt(m,M);
		}
		Statement compound(Statement[] stms){
			static class CompoundStm: Statement{
				Statement[] stms;
				this(Statement[] stms){
					this.stms=stms;
				}
				override void toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName){
					for(int i=0; i<stms.length; ++i)
						if(stms[i])
							stms[i].toPRISM(outStream, tempVars, instCtr, mangName);
				}
			}
			return new CompoundStm(stms);
		}
		Statement skip(){
			static class Skip: Statement{
				override void toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName){}
			}
			return new Skip();
		}
		Statement new_(){
			static class NewStm: Statement{
				override void toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName){
					string output = "[] "~mangName~"pc="~to!string(instCtr);
					UpdateList newUL;
					newUL ~= q(mangName~"pc","-1");
					newUL ~= q(mangName~"ra",to!string(instCtr+1));
					output ~= updateListToPRISM(newUL);
					outStream ~= output;
					++instCtr;
				}
			}
			return new NewStm();
		}
		Statement dup(){
			static class DupStm: Statement{
				override void toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName){
					string output = "[] "~mangName~"pc="~to!string(instCtr);
					UpdateList dupUL;
					dupUL ~= q(mangName~"pc","-2");
					dupUL ~= q(mangName~"ra",to!string(instCtr+1));
					output ~= updateListToPRISM(dupUL);
					outStream ~= output;
					++instCtr;
				}
			}
			return new DupStm();
		}
		Statement drop(){
			static class DropStm: Statement{
				override void toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName){
					string output = "[] "~mangName~"pc="~to!string(instCtr);
					UpdateList dropUL;
					dropUL ~= q(mangName~"pc","-3");
					dropUL ~= q(mangName~"ra",to!string(instCtr+1));
					output ~= updateListToPRISM(dropUL);
					outStream ~= output;
					++instCtr;
				}
			}
			return new DropStm();
		}
		Statement fwd(Expression port){
			static class FwdStm: Statement{
				Expression port;
				this(Expression port){ this.port=port; }
				override void toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName){
					string portStr = port.toPRISM(outStream, tempVars, instCtr, mangName);
					string output = "[] "~mangName~"pc="~to!string(instCtr);
					UpdateList fwdUL;
					fwdUL ~= q(mangName~"opt",portStr);
					fwdUL ~= q(mangName~"pc","-4");
					fwdUL ~= q(mangName~"ra",to!string(instCtr+1));
					output ~= updateListToPRISM(fwdUL);
					outStream ~= output;
					++instCtr;
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
				override void toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName){
					string cndStr = cnd.toPRISM(outStream, tempVars, instCtr, mangName);
					string thenStream = "", elseStream = "";
					int atCondInst = instCtr;
					++instCtr;
					then.toPRISM(thenStream, tempVars, instCtr, mangName);
					int afterThenInst = instCtr;
					++instCtr;
					if(othw)
						othw.toPRISM(elseStream, tempVars, instCtr, mangName);
					int afterElseInst = instCtr;
					string output_true = "[] "~mangName~"pc="~to!string(atCondInst)~" & "~cndStr;
					output_true ~= updateListToPRISM([q(mangName~"pc",to!string(atCondInst+1))]);
					string output_false = "[] "~mangName~"pc="~to!string(atCondInst)~" & !("~cndStr~")";
					output_false ~= updateListToPRISM([q(mangName~"pc",to!string(afterThenInst+1))]);
					string output_skip = "[] "~mangName~"pc="~to!string(afterThenInst);
					output_skip ~= updateListToPRISM([q(mangName~"pc",to!string(afterElseInst))]);
					outStream ~= output_true~output_false~thenStream~output_skip~elseStream;
				}
			}
			return new IteStm(cnd,then,othw);
		}
		Statement observe(Expression e){
			static class ObserveStm: Statement{
				Expression e;
				this(Expression e){ this.e=e; }
				override void toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName){
					string cndStr = e.toPRISM(outStream, tempVars, instCtr, mangName);
					string output_true = "[] "~mangName~"pc="~to!string(instCtr)~" & "~cndStr;
					output_true ~= updateListToPRISM([q(mangName~"pc",to!string(instCtr+1))]);
					string output_false = "[] "~mangName~"pc="~to!string(instCtr)~" & !("~cndStr~")";
					UpdateList obsUL;
					obsUL ~= q(mangName~"pc","0");
					obsUL ~= q("obsrvOK","false");
					output_false ~= updateListToPRISM(obsUL);
					outStream ~= output_true~output_false;
					++instCtr;
				}
			}
			return new ObserveStm(e);
		}
		Statement assert_(Expression e){
			static class AssertStm: Statement{
				Expression e;
				this(Expression e){ this.e=e; }
				override void toPRISM(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName){
					string cndStr = e.toPRISM(outStream, tempVars, instCtr, mangName);
					string output_true = "[] "~mangName~"pc="~to!string(instCtr)~" & "~cndStr;
					output_true ~= updateListToPRISM([q(mangName~"pc",to!string(instCtr+1))]);
					string output_false = "[] "~mangName~"pc="~to!string(instCtr)~" & !("~cndStr~")";
					UpdateList assrtUL;
					assrtUL ~= q(mangName~"pc","0");
					assrtUL ~= q("assrtOK","false");
					output_false ~= updateListToPRISM(assrtUL);
					outStream ~= output_true~output_false;
					++instCtr;
				}
			}
			return new AssertStm(e);
		}
		void addStatement(Label loc,Statement stm){
			stms~=stm;
		}
		string toPRISM(string nodeName){
			string qSize = capacity.toString();
			string mangName = mangleNode(nodeName);
			string startModule = "module "~mangName~"\n";
			string endModule = "endmodule\n";
			string stateVars = state.map!(v=>mangName~mangleVar(v.name)~":[INTMIN..INTMAX]"~(v.init_?" init "~v.init_:"")~";\n").join("");
			string queueVars = "";
			assert(nodeName in maxPort);
			foreach(ref io; [ "i", "o" ]){
				for(int pos=0; pos<to!int(qSize); ++pos){
					queueVars ~= mangName~io~"p"~to!string(pos)~":[1.."~to!string(max(maxPort[nodeName],2))~"] init 1;";
					foreach(field; packetFields)
						queueVars ~= mangName~io~mangleVar(field.name)~to!string(pos)~":[INTMIN..INTMAX] init 0;";
					queueVars ~= "\n";
				}
				queueVars ~= mangName~io~"s:[0.."~qSize~"] init "~((nodeId[nodeName]==0 && io=="i")?"1":"0")~";\n";
			}
			queueVars ~= mangName~"opt:[1.."~to!string(max(maxPort[nodeName],2))~"] init 1;\n";
			string newStmt = "[] "~mangName~"is<"~qSize~" & "~mangName~"pc=-1";
			UpdateList newUL;
			newUL ~= q(mangName~"ip0","1");
			foreach(field; packetFields)
				newUL ~= q(mangName~"i"~mangleVar(field.name)~"0","0");
			addDataShiftUpdates(newUL, mangName, "i", 1, to!int(qSize), 0, -1);
			newUL ~= q(mangName~"is",mangName~"is+1");
			newUL ~= q(mangName~"pc",mangName~"ra");
			newStmt ~= updateListToPRISM(newUL);
			newStmt ~= "[] "~mangName~"is="~qSize~" & "~mangName~"pc=-1";
			newStmt ~= updateListToPRISM([q(mangName~"pc",mangName~"ra")]);
			string dupStmt = "[] "~mangName~"is=0 & "~mangName~"pc=-2";
			dupStmt ~= updateListToPRISM([q(mangName~"pc",mangName~"ra")]);
			dupStmt ~= "[] "~mangName~"is>0 & "~mangName~"is<"~qSize~" & "~mangName~"pc=-2";
			UpdateList dupUL;
			addDataShiftUpdates(dupUL, mangName, "i", 1, to!int(qSize), 0, -1);
			dupUL ~= q(mangName~"is",mangName~"is+1");
			dupUL ~= q(mangName~"pc",mangName~"ra");
			dupStmt ~= updateListToPRISM(dupUL);
			dupStmt ~= "[] "~mangName~"is="~qSize~" & "~mangName~"pc=-2";
			dupStmt ~= updateListToPRISM([q(mangName~"pc",mangName~"ra")]);
			string dropStmt = "[] "~mangName~"is=0 & "~mangName~"pc=-3";
			dropStmt ~= updateListToPRISM([q(mangName~"pc",mangName~"ra")]);
			dropStmt ~= "[] "~mangName~"is>0 & "~mangName~"pc=-3";
			UpdateList dropUL;
			addDataShiftUpdates(dropUL, mangName, "i", 1, to!int(qSize), -1, 0);
			dropUL ~= q(mangName~"is",mangName~"is-1");
			dropUL ~= q(mangName~"pc",mangName~"ra");
			dropStmt ~= updateListToPRISM(dropUL);
			string fwdStmt = "";
			for(int pos=0; pos<to!int(qSize); ++pos){
				fwdStmt ~= "[] "~mangName~"os="~to!string(pos)~" & "~mangName~"pc=-4";
				UpdateList fwdUL;
				fwdUL ~= q(mangName~"op"~to!string(pos),mangName~"opt");
				foreach(field; packetFields)
					fwdUL ~= q(mangName~"o"~mangleVar(field.name)~to!string(pos),mangName~"i"~mangleVar(field.name)~"0");
				fwdUL ~= q(mangName~"os",to!string(pos+1));
				fwdUL ~= q(mangName~"pc","-3");
				fwdStmt ~= updateListToPRISM(fwdUL);
			}
			fwdStmt ~= "[] "~mangName~"os="~qSize~" & "~mangName~"pc=-4";
			fwdStmt ~= updateListToPRISM([q(mangName~"pc","-3")]);
			string fwdAct = "";
			foreach(srcNodeName, srcPorts; links){
				foreach(srcPort, dest; srcPorts){
					if(srcNodeName == nodeName){
						for(int pos=0; pos<to!int(qSize); ++pos){
							fwdAct ~= "["~mangleNode(dest[0])~"f"~to!string(dest[1])~"] "~mangName~"is="~to!string(pos);
							UpdateList fwdUL;
							fwdUL ~= q(mangName~"ip"~to!string(pos),to!string(srcPort));
							foreach(field; packetFields)
								fwdUL ~= q(mangName~"i"~mangleVar(field.name)~to!string(pos),mangleNode(dest[0])~"o"~mangleVar(field.name)~"0");
							fwdUL ~= q(mangName~"is",to!string(pos+1));
							fwdAct ~= updateListToPRISM(fwdUL);
						}
						fwdAct ~= "["~mangleNode(dest[0])~"f"~to!string(dest[1])~"] "~mangName~"is="~qSize;
						fwdAct ~= updateListToPRISM([]);
					}
				}
			}
			fwdAct ~= "[] unlk & numSteps<maxNumSteps & "~mangName~"pc=0 & "~mangName~"os>0";
			UpdateList fwdStartUL;
			fwdStartUL ~= q(mangName~"pc","-5");
			fwdStartUL ~= q("unlk","false");
			fwdAct ~= updateListToPRISM(fwdStartUL);
			foreach(srcNodeName, srcPorts; links){
				foreach(srcPort, dest; srcPorts){
					if(srcNodeName == nodeName){
						fwdAct ~= "["~mangName~"f"~to!string(srcPort)~"] "~mangName~"pc=-5 & "~mangName~"os>0 & "~mangName~"op0="~to!string(srcPort);
						UpdateList fwdUL;
						addDataShiftUpdates(fwdUL, mangName, "o", 1, to!int(qSize), -1, 0);
						fwdUL ~= q(mangName~"os",mangName~"os-1");
						fwdUL ~= q(mangName~"pc","-6");
						fwdAct ~= updateListToPRISM(fwdUL);
					}
				}
			}
			fwdAct ~= "[] numSteps<maxNumSteps & "~mangName~"pc=-6";
			UpdateList fwdEndUL;
			fwdEndUL ~= q(mangName~"pc","0");
			fwdEndUL ~= q("unlk","true");
			fwdEndUL ~= q("numSteps","numSteps+1");
			fwdAct ~= updateListToPRISM(fwdEndUL);
			TempVarData tvd;
			string runAct = "[] unlk & numSteps<maxNumSteps & "~mangName~"pc=0 & "~mangName~"is>0";
			UpdateList runStartUL;
			runStartUL ~= q(mangName~"pc","1");
			runStartUL ~= q("unlk","false");
			runAct ~= updateListToPRISM(runStartUL);
			int instCtr=1;
			for(int i=0; i<stms.length; ++i){
				if(!stms[i])
					continue;
				stms[i].toPRISM(runAct,tvd,instCtr,mangName);
			}
			runAct ~= "[] numSteps<maxNumSteps & "~mangName~"pc="~to!string(instCtr);
			UpdateList runEndUL;
			runEndUL ~= q(mangName~"pc","0");
			runEndUL ~= q("unlk","true");
			runEndUL ~= q("numSteps","numSteps+1");
			runAct ~= updateListToPRISM(runEndUL);
			//(ref string outStream, ref TempVarData tempVars, ref int instCtr, string mangName)
			string tempVars = "";
			for(int cnt=0; cnt<tvd.count; ++cnt)
				tempVars ~= mangName~"t"~to!string(cnt)~":["~to!string(tvd.ranges[cnt][0])~".."~to!string(tvd.ranges[cnt][1])~"];\n";
			string instVars = mangName~"pc:[-6.."~to!string(instCtr)~"] init 0; "~mangName~"ra:[-6.."~to!string(instCtr)~"] init 0;\n";
			return startModule~stateVars~tempVars~queueVars~instVars~newStmt~dupStmt~dropStmt~fwdStmt~fwdAct~runAct~endModule;
		}
	private:
		void addDataShiftUpdates(ref UpdateList updateList, string mangName, string io, int begin, int end, int dest_offset, int src_offset){
			for(int pos=begin; pos<end; ++pos){
				updateList ~= q(mangName~io~"p"~to!string(pos+dest_offset),mangName~io~"p"~to!string(pos+src_offset));
				foreach(field; packetFields)
					updateList ~= q(mangName~io~mangleVar(field.name)~to!string(pos+dest_offset),mangName~io~mangleVar(field.name)~to!string(pos+src_offset));
			}
		}
		static string updateListToPRISM(UpdateList updates){
			if(updates.length){
				return " -> "~(updates.map!(u=>"("~u[0]~"'="~u[1]~")").join("&"))~";\n";
			}else{
				return " -> true;\n";
			}
		}
		static string updateListToPRISM_pure(UpdateList updates){
			if(updates.length){
				return updates.map!(u=>"("~u[0]~"'="~u[1]~")").join("&");
			}else{
				return "true";
			}
		}
		Variable[] state;
		void[0][string] stateSet;
		Statement[] stms;
	}
	void addNode(string name)in{assert(name !in nodeId);}body{
		nodeId[name]=cast(int)nodes.length;
		nodes~=name;
	}
	void addLink(InterfaceDecl a,InterfaceDecl b){
		auto x=q(a.node.name,a.port), y=q(b.node.name,b.port);
		links[x[0]][x[1]]=y;
		if(!(x[0] in maxPort) || x[1]>maxPort[x[0]])
			maxPort[x[0]] = x[1];
		links[y[0]][y[1]]=x;
		if(!(y[0] in maxPort) || y[1]>maxPort[y[0]])
			maxPort[y[0]] = y[1];
	}
	void addParam(ParameterDecl p){
		params~=p;
	}
	void addPacketField(string name){
		packetFields~=new Variable(name,"int");
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
	Program addProgram(string name){
		auto r=new Program(name);
		programs~=r;
		return r;
	}
	void addProgram(string node,string name)in{assert(node in nodeId);}body{
		foreach(i,p;programs) if(p.name==name){ // TODO: replace linear lookup
			nodeProg[nodeId[node]]=cast(int)i;
			return;
		}
		assert(0);
	}
	void addPostObserve(Expression decl){
		postObserves~=decl;
	}
	string toPRISM(){
		string header = "dtmc\nglobal unlk:bool init true;\nglobal assrtOK:bool init true;\nglobal obsrvOK:bool init true;"
		                ~"\nconst int INTMIN = 0; const int INTMAX = 255;"
		                ~"\nconst int maxNumSteps = "~num_steps.toString()~";\nglobal numSteps:[0..maxNumSteps] init 0;\n";
		//assume parameters are integers - any way to find out otherwise?
		string paramdef = params.map!(p=>"const int "~mangleVar(p.name.toString())~" = "~(p.init_?p.init_.toString():"?"~p.name.toString())~";\n").join("");
		string modules = "";
		foreach(nodeid, progid; nodeProg){
			modules ~= programs[progid].toPRISM(nodes[nodeid]);
		}
		finishedCondition = "unlk"~nodes.map!(n=>" & "~mangleNode(n)~"is=0 & "~mangleNode(n)~"os=0").join();
		modules ~= "module finisher\nfinished:bool init false;\n[] !finished & assrtOK & "~finishedCondition~" -> (finished'=true);\nendmodule\n";
		string queries = formatQueries();
		//TODO post observes and nonterminal asserts?
		return header~paramdef~modules~queries;
	}
private:
	static string mangleNode(string nodeName){
		return "n"~to!string(nodeName.length)~nodeName;
	}
	static string mangleVar(string varName){
		return "v"~to!string(varName.length)~varName;
	}
	string formatQueries(){
		string rewards="";
		int rewardCtr=0;
		string formatQuery(Expression q){
			string translateExpression(Expression exp){
				if(auto be=cast(ABinaryExp)exp){
					if(be.operator=="@")
						return mangleNode(be.e2.toString())~translateExpression(be.e1);
					auto e1=translateExpression(be.e1);
					auto e2=translateExpression(be.e2);
					string op="";
					if(be.operator=="or" || be.operator=="||") op="|";
					else if(be.operator=="and" || be.operator=="&&") op="&";
					else if(be.operator=="==") op="=";
					else op=be.operator;
					return "("~e1~op~e2~")";
				}else if(auto id=cast(Identifier)exp){
					return mangleVar(id.name);
				}else if(auto lit=cast(LiteralExp)exp){
					assert(lit.lit.type==Tok!"0",text("TODO: ",lit));
					return lit.lit.str;
				}else if(auto ce=cast(CallExp)exp){
					assert(0,text("Call epression unsupported inside queries by PRISM backend"));
				}else if(auto be=cast(BuiltInExp)exp){
					assert(0,text("Builtin epression unsupported inside queries by PRISM backend"));
				}else if(auto fe=cast(FieldExp)exp){
					assert(0,text("Field epression unsupported inside queries by PRISM backend"));
				}
				assert(0,text("TODO: ",exp));
			}
			if(auto ce=cast(CallExp)q){
				if(auto id=cast(Identifier)ce.e){
					if(id.name=="probability"){
						return "//  P=? [ F finished & assrtOK & obsrvOK & "~translateExpression(ce.args[0])~" ] / P=? [ F finished & obsrvOK ]";
					}if(id.name=="expectation"){
						string rewardName = "\"exp"~to!string(rewardCtr++)~"\"";
						rewards ~= "rewards "~rewardName~"\n!finished & "~finishedCondition~" : "~translateExpression(ce.args[0])~";\nendrewards\n";
						return "//  R{"~rewardName~"}=? [ F finished ]";
					}
				}
			}
			assert(0,text("Only probability queries and expectation queries supported by PRISM backend"));
		}
		string properties = queries.map!(q=>formatQuery(q)).join("\n");
		return rewards~"\n//Properties\n\n"~properties;
	}
	string finishedCondition;
	Variable[] packetFields;
	Program[] programs;
	string[] nodes;
	ParameterDecl[] params;
	int[string] nodeId;
	int[int] nodeProg;
	Q!(string,int)[int][string] links;
	int[string] maxPort;
	FunctionDef scheduler;
	Expression[] queries;
	Expression num_steps;
	Expression capacity;
	Expression[] postObserves;
}

string translate(Expression[] exprs, Builder bld){
	string[] paramNames;
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
	if(params)
		foreach(prm;params.params){
			bld.addParam(prm);
			paramNames ~= prm.name.toString();
		}
	auto pfld=all!PacketFieldsDecl[0];
	foreach(f;pfld.fields) bld.addPacketField(f.name.name);
	auto pdcl=all!ProgramsDecl[0];
	bld.addNumSteps(all!NumStepsDecl[0]);
	assert(all!QueueCapacityDecl.length); //required for PRISM backend
	bld.addQueueCapacity(all!QueueCapacityDecl[0]);
	foreach(q;all!QueryDecl) bld.addQuery(q);
	void translateFun(FunctionDef fdef){
		auto prg=bld.addProgram(fdef.name.name);
		Builder.Program.Expression translateExpression(Expression exp){
			if(auto be=cast(ABinaryExp)exp){
				auto e1=translateExpression(be.e1);
				auto e2=translateExpression(be.e2);
				return prg.binary(e1,e2,be.operator);
			}else if(auto id=cast(Identifier)exp){
				foreach(s;paramNames)
					if(s == id.name)
						return prg.read(id.name,1);
				foreach(i,n;topology.nodes)
					if(n.name.name == id.name)
						return prg.read(to!string(i),2);
				return prg.read(id.name,0);
			}else if(auto lit=cast(LiteralExp)exp){
				assert(lit.lit.type==Tok!"0",text("TODO: ",lit));
				return prg.literal(to!int(lit.lit.str));
			}else if(auto ce=cast(CallExp)exp){
				auto callee=cast(Identifier)ce.e;
				assert(callee);
				if(callee.name=="flip"){
					assert(ce.args.length==1);
					auto trueProbInt=cast(LiteralExp)ce.args[0];
					auto trueProbFrac=cast(ABinaryExp)ce.args[0];
					assert(trueProbInt || trueProbFrac);
					double trueProbDbl;
					if(trueProbInt){
						trueProbDbl=to!double(trueProbInt.lit.str);
					}else if(trueProbFrac){
						auto numerator=cast(LiteralExp)trueProbFrac.e1;
						auto denominator=cast(LiteralExp)trueProbFrac.e2;
						assert(numerator && denominator);
						trueProbDbl=to!double(numerator.lit.str)/to!double(denominator.lit.str);
					}
					return prg.flip(trueProbDbl);
				}else if(callee.name=="uniformInt"){
					assert(ce.args.length==2);
					auto minInt=cast(LiteralExp)ce.args[0];
					auto maxInt=cast(LiteralExp)ce.args[1];
					assert(minInt && maxInt);
					return prg.uniformInt(to!int(minInt.lit.str),to!int(maxInt.lit.str));
				}else{
					assert(0);
				}
			/*}else if(auto ite=cast(IteExp)exp){
				auto cond=translateExpression(ite.cond);
				Expression getIt(Expression e){
					auto ce=cast(CompoundExp)e;
					assert(ce&&ce.s.length==1);
					return ce.s[0];
				}
				return prg.ite(cond,translateExpression(getIt(ite.then)),translateExpression(getIt(ite.othw)));*/
			}else if(auto be=cast(BuiltInExp)exp){
				if(be.which==Tok!"FwdQ") return prg.literal(0);
				if(be.which==Tok!"RunSw") return prg.literal(1);
			}else if(auto fe=cast(FieldExp)exp){
				return prg.field(translateExpression(fe.e),fe.f.name);
			}
			assert(0,text("TODO: ",exp));
		}
		if(fdef.state)
			foreach(sd;fdef.state.vars){
				if(sd.init_){
					auto initLit=cast(LiteralExp)sd.init_;
					assert(initLit);
					prg.addState(sd.name.name,initLit.lit.str);
				}else{
					prg.addState(sd.name.name,"");
				}
			}
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
				override void toPRISM(ref string outStream, ref Builder.Program.TempVarData tempVars, ref int instCtr, string mangName){
					outStream ~= "/+ TODO: "~stm.toString()~"+/\n";
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
		if(fdef.name.name=="scheduler") {}//bld.addScheduler(fdef);
		else translateFun(fdef);
	}
	foreach(m;pdcl.mappings) bld.addProgram(m.node.name,m.prg.name);
	foreach(p;all!PostObserveDecl) bld.addPostObserve(p.e);
	return bld.toPRISM();
}
