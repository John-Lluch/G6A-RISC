//
//  MachineParts.swift
//  g6a-sim
//
//  Created by Joan on 17/08/19.
//  Copyright © 2019 Joan. All rights reserved.
//

import Foundation

private let ProgramMemorySize = 0x10000*2     // 128 kb program memory
private let DataMemorySize    = 0x10000       // 64 kb data memory

//-------------------------------------------------------------------------------------------
// Extension utilities
extension UInt16
{
  var i16:Int16    { return Int16(truncatingIfNeeded:self) }
  var lo:UInt8     { return UInt8(self & 0xff) }
  var hi:UInt8     { return UInt8(self >> 8) }
  var i:Int        { return Int(self) }
  var b:Bool       { return (self != 0) }
  var s:Bool       { return (self & 0x8000) != 0 }
  
  subscript( end:UInt16, beg:UInt16 ) -> UInt16 {
    get { return (self<<(15-end)) >> (15-end+beg) }
    set(v) { self = (self>>(end+1))<<(end+1) | (self<<(16-beg))>>(16-beg) | (v<<beg) }}
  
  subscript( bit:UInt16 ) -> Bool {
    get { return (self & (1<<bit)) != 0 }
    set(v) { self = ( self & ~(1<<bit)) | (v.u16<<bit) } }

  func sext( _ end:UInt16, _ beg:UInt16 ) -> UInt16 { return ((self.i16 << (15-end)) >> (15-end+beg)).u16 }
  var zext:UInt16  { return self[7,0] }
  var sext:UInt16  { return sext(7,0) }
  init(lo:UInt8, hi:UInt8) { self = UInt16(hi)<<8 | UInt16(lo) }
}

extension Int16 {
  var u16:UInt16  { return UInt16(truncatingIfNeeded:self) }
}

extension Int {
  var u16:UInt16 { return UInt16(truncatingIfNeeded:self) }
}

extension Bool {
  var u16:UInt16  { return UInt16(self ? 1 : 0 ) }
}

extension UInt8 {
  var u16:UInt16  { return UInt16(truncatingIfNeeded:self) }
}

//-------------------------------------------------------------------------------------------
class ProgramMemory
{
  // Memory size
  var size:UInt16 { return (memory.count/2).u16 }   // size in words

  // Memory, private
  private var memory = Data(count:ProgramMemorySize)
  subscript (address: UInt16) -> UInt16
  {
    get { return UInt16(lo:memory[address.i*2], hi:memory[address.i*2+1]) }
  }

  // Store program utility
  func storeProgram(atAddress address:UInt16, withData data:Data )
  {
    if ( data.count > address.i*2 + memory.count) { out.exitWithError( "Program exceeds program memory size" ) }
    if ( data.count % 2 != 0 ) { out.exitWithError( "Program must have an even number of bytes" ) }
    memory.replaceSubrange( address.i*2..<data.count , with:data )
  }
}

//-------------------------------------------------------------------------------------------
class DataMemory
{
  // Memory address register (write only)
  var mar:UInt16 = 0
  
  // Memory value at current address // (get/set)
  var value:UInt16
  {
    get { return self[mar] }
    set(v) { self[mar] = v }
  }

  // Memory size
  var size:UInt16 { return memory.count.u16 }   // size in bytes
  
  // Memory, private
  private var memory = Data(count:DataMemorySize)
  private subscript (address:UInt16) -> UInt16
  {
    get { return UInt16(lo:memory[address.i*2], hi:memory[address.i*2+1]) }
    set (v) { memory[address.i*2] = v.lo; memory[address.i*2+1] = v.hi }
  }
}

//-------------------------------------------------------------------------------------------
class Registers : CustomDebugStringConvertible
{
  var regs = [UInt16](repeating:0, count:8)
  subscript(r:UInt16) -> UInt16 { get { return regs[r.i] } set(v) { regs[r.i] = v } }
  
  var debugDescription: String
  {
    var str = String()
    for i in 0..<8
    {
      str += String(format:"\tr%d=%04X", i, regs[i])
      str += ", "
    }
  
//    str += "\n\t\t\t\t\t\t\t\t\t"
//    for i in stride(from:0, to:8, by:2)
//    {
//      if ( i != 0 ) { str += ", " }
//      str += String(format:"\tr%d:r%d=%d", i, i+1, Int(regs[i]) | Int(regs[i+1])<<16 )
//    }
    
    return str
  }
}

//-------------------------------------------------------------------------------------------
class Condition
{
  var z:Bool = false
  var c:Bool = false
  var s:Bool = false
  var v:Bool = false
}

class Status
{
  var z:Bool = false
  var c:Bool = false
  var t:Bool = false
}

enum CC : UInt16 { case eq = 0, ne, uge, ult, ge, lt, ugt, gt }

//-------------------------------------------------------------------------------------------

enum ALUOp2 : UInt16 { case adda, add, addc, suba, sub, subc, or, and, xor, cmp }
enum ALUOp1 : UInt16 { case lsr, lsl, asr, neg, not, inca, deca, zext, sext, bswap, sextw }

class ALU
{
  var sr = Status()
  
  // Adder, returns result and flags
  func adder( _ a:UInt16, _ b:UInt16, c:Bool, z:Bool=true) -> (res:UInt16, ct:Condition)
  {
    let ct = Condition()
    let res32 = UInt32(a) + UInt32(b) + UInt32(c.u16)
    let res = UInt16(truncatingIfNeeded:res32)
    ct.z = z && (res == 0)
    ct.c = res32 > 0xffff
    ct.s = res.s
    ct.v = (!a.s && !b.s && res.s) || (a.s && b.s && !res.s )
    return ( res, ct )
  }
  
  // Decimal Adder, returns result and flags
  func dadder( _ a:UInt16, _ b:UInt16, c:Bool, z:Bool=true) -> (res:UInt16, ct:Condition)
  {
    let ct = Condition()
    let binsum = UInt32(a) + UInt32(b) + UInt32(c.u16)
    let carry = ((binsum + UInt32(0x06666666)) ^ UInt32(a) ^ UInt32(b)) & UInt32(0x11111110)
    let res32 = (binsum + ((carry - (carry>>4)) & UInt32(0x06666666)))
    let res = UInt16(truncatingIfNeeded:res32)
    ct.z = z && (res == 0)
    ct.c = res32 > 0x9999
    ct.s = res.s
    ct.v = (!a.s && !b.s && res.s) || (a.s && b.s && !res.s )
    return ( res, ct )
  }
  
  // Set logical operation flags
  private func setz( z:Bool )
  {
    sr.z = z
    sr.c = false
    sr.t = z
  }
  
  // Set shift operation flags
  private func setzc( z:Bool, c:Bool )
  {
    sr.z = z
    sr.c = c
    sr.t = c
  }
  
  // Set arithmetic operation flags based on condition
  private func setsr( _ cc:CC, _ ct:Condition )
  {
    sr.z = ct.z
    sr.c = ct.c
    switch cc
    {
      case .eq : sr.t = ct.z
      case .ne : sr.t = !ct.z
      case .uge: sr.t = ct.c   // ATENCIO BUG !!
      case .ult: sr.t = !ct.c  // ATENCIO BUG !!
      case .ge : sr.t = ct.s == ct.v
      case .lt : sr.t = ct.s != ct.v
      case .ugt: sr.t = ct.c && !ct.z
      case .gt : sr.t = (ct.s == ct.v) && !ct.z
    }
  }
  
  func setsr( _ cc:UInt16, _ ct:Condition ) {
    setsr( CC(rawValue:cc)!, ct )
  }
  
  // Operations
  
  func cmp ( _ cc:UInt16, _ a:UInt16, _ b:UInt16 ) -> UInt16 { let res = adder(a,~b, c:true) ; setsr(cc, res.ct) ; return res.res }
  func cpc ( _ cc:UInt16, _ a:UInt16, _ b:UInt16 ) -> UInt16 { let res = adder(a,~b, c:sr.c, z:sr.z) ; setsr(cc, res.ct) ; return res.res }
  
  func lda ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { return a }
  func ldb ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { return b }
  
  func add ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { let res = adder(a,b, c:false); setsr(.eq, res.ct) ; return res.res }
  func adc ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { let res = adder(a,b, c:sr.c, z:sr.z); setsr(.eq, res.ct) ; return res.res }
  
  func sub ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { let res = adder(a,~b, c:true); setsr(.eq, res.ct) ; return res.res }
  func sbc ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { let res = adder(a,~b, c:sr.c, z:sr.z); setsr(.eq, res.ct) ; return res.res }
  
  func rsb ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { return sub(b,a) }

  func dad ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { let res = dadder(a,b, c:false); setsr(.eq, res.ct) ; return res.res }
  func dac ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { let res = dadder(a,b, c:sr.c, z:sr.z); setsr(.eq, res.ct) ; return res.res }
  
  func dsb ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { let res = dadder(a,0x9999-b, c:true, z:sr.z); setsr(.eq, res.ct) ; return res.res }
  func dsc ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { let res = dadder(a,0x9999-b, c:sr.c, z:sr.z); setsr(.eq, res.ct) ; return res.res }
  
  func or  ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { let res = a | b ; setz(z:res==0) ; return res }
  func and ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { let res = a & b ; setz(z:res==0) ; return res }
  func xor ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { let res = a ^ b ; setz(z:res==0) ; return res }
  
  func sr1 ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { var res = a >> 1 ; res[15,15] = 0 ;      setzc(z:res==0, c:a[0,0] != 0) ; return res }
  func sr4 ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { var res = a >> 4 ; res[15,12] = 0 ;      setzc(z:res==0, c:a[3,0] != 0) ; return res }
  func rr1 ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { var res = a >> 1 ; res[15,15] = b[1,1] ; setzc(z:res==0, c:a[0,0] != 0) ; return res }
  func rr4 ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { var res = a >> 4 ; res[15,12] = b[3,0] ; setzc(z:res==0, c:a[3,0] != 0) ; return res }
  
  func sl1 ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { var res = a << 1 ; res[0,0] = 0 ;        setzc(z:res==0, c:a[15,15] != 0) ; return res }
  func sl4 ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { var res = a << 4 ; res[3,0] = 0 ;        setzc(z:res==0, c:a[15,12] != 0) ; return res }
  func rl1 ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { var res = a >> 1 ; res[0,0] = b[15,15] ; setzc(z:res==0, c:a[15,15] != 0) ; return res }
  func rl4 ( _ a:UInt16, _ b:UInt16 ) -> UInt16 { var res = a >> 4 ; res[3,0] = b[15,12] ; setzc(z:res==0, c:a[15,12] != 0) ; return res }
}


