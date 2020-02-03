//
//  Machine.swift
//  c74-sim
//
//  Created by Joan on 17/08/19.
//  Copyright © 2019 Joan. All rights reserved.
//

import Foundation



//func nand(_ a:Bool, _ b:Bool) -> Bool { return !(a && b) }
//func nand(_ a:Bool, _ b:Bool, _ c:Bool) -> Bool { return !(a && b && c) }
//func nor(_ a:Bool, _ b:Bool) -> Bool { return !(a || b) }
//func nor(_ a:Bool, _ b:Bool, _ c:Bool) -> Bool { return !(a || b || c) }
//func and(_ a:Bool, _ b:Bool) -> Bool { return (a && b) }
//func and(_ a:Bool, _ b:Bool, _ c:Bool) -> Bool { return (a && b && c) }
//func or(_ a:Bool, _ b:Bool) -> Bool { return (a || b) }
//func or(_ a:Bool, _ b:Bool, _ c:Bool) -> Bool { return (a || b || c) }

// Describes a machine with all its components
class Machine
{
  // Registers, Program memory, Data memory, ALU
  let reg = Registers()
  let prg = ProgramMemory()
  let mem = DataMemory()
  let alu = ALU()
  
  // Instruction register and others
  var ir:UInt16 = 0    // Instruction register
  var pfr:UInt16 = 0   // Prefix register
  var pcInc:UInt16 = 0  // Increment register
  
  // Operands and result
  var a:UInt16 = 0
  var b:UInt16 = 0
  var q:UInt16 = 0
  var cc:UInt16 = 0
  
  // Control
  var sto = false
  var wi_r:Bool = false
  var ie_pfr:Bool = false
  
  // Operation
  var function:(Machine)->()->() = pfx
  var mc_halt = false
  
  // Instruction Definitions
  
  func sr1()  { q = alu.sr1(a, b) }
  func sl1()  { q = alu.sl1(a, b) }
  func cmp()  { wi_r = true ; q = alu.cmp(cc, a, b) }
  func mov()  { q = sto ? alu.lda(a,b) : alu.ldb(a,b) }
  func add()  { q = alu.add(a, b) }
  func adc()  { q = alu.adc(a, b) }
  func dad()  { q = alu.dad(a, b) }
  func dac()  { q = alu.dac(a, b) }
  
  func rr1()  { q = alu.rr1(a, b) }
  func rl1()  { q = alu.rl1(a, b) }
  func cpc()  { wi_r = true ; q = alu.cpc(cc, a, b) }
  func mvl()  { reg[6] = 1+reg[7] ; q = alu.ldb(a, b) }
  func sub()  { q = sto ? alu.sub(b, a) : alu.sub(a, b) }
  func sbc()  { q = sto ? alu.sbc(b, a) : alu.sbc(a, b) }
  func dsb()  { q = sto ? alu.dsb(b, a) : alu.dsb(a, b) }
  func dsc()  { q = sto ? alu.dsc(b, a) : alu.dsc(a, b) }
  
  func sr4()  { q = alu.sr4(a, b) }
  func sl4()  { q = alu.sl4(a, b)}
  func set()  { q = alu.sr.t ? alu.ldb(a, b) : 0 }
  func __0()  {  }
  func adt()  { wi_r = !alu.sr.t ; q = alu.adda(a, b) }
  func adf()  { wi_r = alu.sr.t ; q = alu.adda(a, b) }
  func or ()  { q = alu.or(a, b)  }
  func and()  { q = alu.and(a, b) }
  
  func rr4()  { q = alu.rr4(a, b) }
  func rl4()  { q = alu.rl4(a, b) }
  func sef()  { q = !alu.sr.t ? alu.ldb(a, b) : 0 }
  func sel()  { q = alu.sr.t ? alu.ldb(a, b) : alu.lda(a, b) }
  func sbt()  { wi_r = !alu.sr.t ; q = alu.suba(a, b) }
  func sbf()  { wi_r = alu.sr.t ; q = alu.suba(a, b) }
  func xor()  { q = alu.xor(a, b) }
  func rsb()  { q = sto ? alu.rsb(b, a) : alu.rsb(a, b)  }
  
  func pfx()  { wi_r = true; ie_pfr = true }
  func hlt()  { wi_r = true; mc_halt = true }
  func __2()  {  }
  func lp()   { q = prg[alu.ldb(a, b)] }
  func __3()  {  }
  func __4()  {  }
  func r0a()  { q = alu.dad(a, b) }
  func r1a()  { q = alu.dac(a, b) }
  
  // Instruction Encodings

  let instr:Dictionary<UInt16, (Machine)->()->() > =
  [
    0b00_000 : sr1,
    0b00_001 : sl1,
    0b00_010 : cmp,
    0b00_011 : mov,
    0b00_100 : add,
    0b00_101 : adc,
    0b00_110 : dad,
    0b00_111 : dac,
    
    0b01_000 : rr1,
    0b01_001 : rl1,
    0b01_010 : cpc,
    0b01_011 : mvl,
    0b01_100 : sub,
    0b01_101 : sbc,
    0b01_110 : dsb ,
    0b01_111 : dsc,
    
    0b10_000 : sr4,
    0b10_001 : sl4,
    0b10_010 : set,
    0b10_011 : __0,
    0b10_100 : adt,
    0b10_101 : adf,
    0b10_110 : or,
    0b10_111 : and,
    
    0b11_000 : rr4,
    0b11_001 : rl4,
    0b11_010 : sef,
    0b11_011 : sel,
    0b11_100 : sbt,
    0b11_101 : sbf,
    0b11_110 : xor,
    0b11_111 : rsb,
  ]
  
  let instr_ex:Dictionary<UInt16, (Machine)->()->() > =
  [
    0b000 : pfx,
    0b001 : hlt,
    0b010 : __2,
    0b011 : lp,
    0b100 : __3,
    0b101 : __4,
    0b110 : r0a,
    0b111 : r1a,
  ]
  
  //-------------------------------------------------------------------------------------------
  func loadProgram( source:Data )
  {
    prg.storeProgram(atAddress:0, withData:source)
  }
  
  //-------------------------------------------------------------------------------------------
  func reset()
  {
    pfr = 0
    reg[7] = 0
  }
  
  //-------------------------------------------------------------------------------------------
  func cycle()
  {
    // Fetch
    
    wi_r = false
    ie_pfr = false
    mc_halt = false
    ir = prg[reg[7]]
    
    // Fields decode
    
    let irTy    = ir[15,14]
    let irOp    = ir[13,11]
    let irRi    = ir[10,8]
    let irFn    = ir[7,6]
    let irSt    = ir[5,5]
    let irRj    = ir[5,3]
    let irRk    = ir[2,0]
    let irImm5  = ir[4,0]
    let irImm11 = ir[10,0]
    
    let ph1_Ex = irTy == 0 && (irFn == 0 || irOp == 0)
    let ph2_Ex = irTy == 0 && (irFn == 0 || irOp == 0)
  
    let ph1TypeI    = !ph1_Ex && irTy == 0b11
    let ph1TypeR    = !ph1_Ex && irTy == 0b10
    let ph1TypeZPSt = !ph1_Ex && irTy == 0b01 && irSt == 1
    let ph1TypeZPLd = !ph1_Ex && irTy == 0b01 && irSt == 0
    let ph1TypeMSt  = !ph1_Ex && irTy == 0b00 && irSt == 1
    let ph1TypeMLd  = !ph1_Ex && irTy == 0b00 && irSt == 0
    let ph1Ldp      = ph1_Ex && irOp == 0b011
    let ph1R0a      = ph1_Ex && irOp == 0b110
    let ph1R1a      = ph1_Ex && irOp == 0b111
    
    let ph2Mem      = !ph2_Ex && irTy[1] == false && irSt == 1
    let ph2Reg      = !ph2_Ex && (irTy[1] == true || irSt == 0)
    let ph2Ldp      = ph2_Ex && irOp == 0b011
    let ph2R0a      = ph2_Ex && irOp == 0b110
    let ph2R1a      = ph2_Ex && irOp == 0b111
    
    let ph1CC       = ph1TypeR && irOp == 0b010 && irFn[1] == false
    
    let ri = irRi
    let rj = irRj
    let rk = irRk
    let rn = irFn+3
    let k = irImm5 | (pfr << 5)

    if out.logEnabled { logDecode() }
    
    // Instruction opcode Decode
    
    if let f = ph1_Ex ? instr_ex[irOp] : irTy == 0 ? instr[irOp] : instr[(irFn<<3)|irOp]  { function = f }
    else { out.exitWithError( "Unrecognized instruction opcode" ) }
    
    // Exec Phase1
    
    a = 0
    b = 0
    cc = 0
    sto = false
    if ph1TypeI    { a = reg[ri] ; b = k }
    if ph1TypeR    { a = reg[rj] ; b = reg[rk] }
    if ph1TypeZPSt { a = reg[ri] ; mem.mar = k ; b = mem.value }
    if ph1TypeZPLd { a = reg[ri] ; mem.mar = k ; b = mem.value }
    if ph1TypeMSt  { a = reg[ri] ; mem.mar = reg[rn] | k ; b = mem.value }
    if ph1TypeMLd  { a = reg[ri] ; mem.mar = reg[rn] | k ; b = mem.value }
    if ph1Ldp      { a = reg[ri] ; b = reg[rk] }
    if ph1R0a      { a = reg[ri] ; b = reg[0] ; mem.mar = reg[4] | k }
    if ph1R1a      { a = reg[ri] ; b = reg[1] ; mem.mar = reg[4] | k }
    if ph1CC       { cc = irRi }
    if ph1TypeZPSt || ph1TypeMSt { sto = true }
    pcInc = reg[7] + 1
		
    
    function(self)()
    
    // Exec Phase2
    
    pfr = ie_pfr ? irImm11 : 0
    if wi_r || ri != 7 { reg[7] = pcInc }
    if !wi_r && (ph2Reg || ph2Ldp) { reg[ri] = q }
    if !wi_r && ph2Mem { mem.value = q }
    if !wi_r && ph2R0a { reg[0] = q ; mem.value = q }
    if !wi_r && ph2R1a { reg[1] = q ; mem.value = q }
    
    if out.logEnabled { logExecute() }

    return
  }

  //-------------------------------------------------------------------------------------------
  // run
  func run() -> Bool
  {
    var done = false
    while !done  // execute until 'halt' instruction
    {
      cycle()
      if mc_halt
      {
          let pep = out.getKeyPress();
          out.logln( "keyPress : \(pep)" )
          if pep == 27 { done = true }
      }
    }
    return true
  }


  //-------------------------------------------------------------------------------------------
  // Log functions
  
  func logDecode()
  {
    var str_ir = String(ir, radix:2) //binary base
    str_ir = String(repeating:"0", count:(16 - str_ir.count)) + str_ir
    
    let addr = String(format:"%05d", reg[7] )
    let prStr = String(format:"%@ : %@ (%04X)", addr, str_ir, ir )
    out.log( prStr )
  }

  func logExecute()
  {
    out.log( " " )
    out.logln( String(reflecting:reg) )
  }
  
}


