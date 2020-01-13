//
//  MachineInfo.swift
//  c74-as
//
//  Created by Joan on 28/06/19.
//  Copyright © 2019 Joan. All rights reserved.
//

import Foundation

// Machine Instruction attribute flags
struct ReferenceKind: OptionSet
{
  let rawValue:Int
  static let relative = ReferenceKind(rawValue: 1 << 1)      // Relative memory addressing
  static let absolute = ReferenceKind(rawValue: 1 << 2)      // Absolute program addressing
  static let immediate = ReferenceKind(rawValue: 1 << 4)      // Immediate constant
}


//-------------------------------------------------------------------------------
// Machine instruction formats and encoding patterns
//-------------------------------------------------------------------------------

// Base class to represent machine instruction encodings. Objects have a
// single property which is the machine instruction encoding.
class MachineInstr
{
  let refKind:ReferenceKind
  var encoding:UInt16 = 0
  
  // Designated initializer, just sets the encoding to zero
  init( _ kind:ReferenceKind )
  {
    refKind = kind
  }
  
  // Overridable convenience initializer that must be implemented by subclases
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = [])
  {
    self.init( kind )
    encoding = 0
  }
}

// Abstract protocol to represent objects referring Data Memory adresses
// that must be resolved at link time
class InstWithImmediate:MachineInstr
{
  let mask:UInt16
  let offs:Int
  
  init( mask m:UInt16, offs o:Int, kind:ReferenceKind )
  {
    mask = m
    offs = o
    super.init( kind )
  }
  
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = [])
  {
    self.init(mask:0, offs:0, kind:kind)
  }
  
  func setValue( a:UInt16 )
  {
    encoding &= ~(mask << offs)
    encoding |= (mask & a) << offs
  }
  
  func setPrefixedValue( a:UInt16 )
  {
    setValue( a: a & 0b1_1111 )
  }
  
  func inRange( _ v:Int ) -> Bool
  {
    // This tests true only for positive values that fit in the mask size
    // Might be overriden to test sign extended immediates
    return v & Int(mask) == v
  }
  
  func signExtendRange( _ v:Int ) -> Bool
  {
    let half = (Int(mask)+1)/2
    return v >= -half && v < half
  }
}

// Type P

class TypeP:InstWithImmediate
{
  init( op:UInt16, a:UInt16, kind:ReferenceKind )
  {
    super.init(mask:0b111_1111_1111, offs:0, kind:kind )
    encoding |= (0b00)        << 14
    encoding |= (0b111 & op)  << 11
    encoding |= (mask & a)    << offs
  }
  
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = []) {
    self.init( op:op, a:ops[0].u16value, kind:kind ) }
  
  func setPrefixValue( a:UInt16 )
  {
    // Note that this works only because mask and shift do not overlap
    encoding &= ~mask
    encoding |= (mask & (a>>5))
  }
}

// Type I

class TypeI:InstWithImmediate
{
  init( op:UInt16, fn:UInt16, ri:UInt16, k:UInt16, kind:ReferenceKind )
  {
    super.init(mask:0b1_1111, offs:0, kind:kind)
    encoding |= (0b11)        << 14
    encoding |= (0b111 & op)  << 11
    encoding |= (0b111 & ri)  << 8
    encoding |= (0b11 & fn)   << 6
    encoding |= (0b1 & 0b0)   << 5
    encoding |= (mask & k)    << offs
  }
  
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = []) {
    self.init( op:op, fn:fn, ri:ops[1].u16value, k:ops[0].u16value,  kind:kind )
  }
}

// Same as TypeI, but with no operands
class TypeI_0:TypeI
{
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = []) {
    self.init( op:op, fn:fn, ri:0, k:0,  kind:kind )
  }
}

// Same as TypeI, but the destination register is implicitly the PC
class TypeJ:TypeI
{
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = []) {
    self.init( op:op, fn:fn, ri:7, k:ops[0].u16value,  kind:kind )
  }
  
  override func inRange( _ v:Int ) -> Bool {
    // This tests true for positive values that fit in the mask size
    // or negative values which complement would also fit
    return abs(v) <= Int(mask)
  }
  
  func setBackwards()
  {
    if (encoding >> 11) & 0b111 == 0b100 { encoding |= 0b1 << 11 }  // convert b+ into b-
    else if (encoding >> 11) & 0b111 == 0b111 { encoding |= 0b1 << 7 } // convert bt+, bf+ into bt-, bf-
  }
}

// Type ZP

class TypeZP:InstWithImmediate
{
  init( op:UInt16, fn:UInt16, s:UInt16, ri:UInt16, a:UInt16, kind:ReferenceKind )
  {
    super.init(mask:0b1_1111, offs:0, kind:kind)
    encoding |= (0b01)        << 14
    encoding |= (0b111 & op)  << 11
    encoding |= (0b111 & ri)  << 8
    encoding |= (0b11 & fn)   << 6
    encoding |= (0b1 & s)     << 5
    encoding |= (mask & a)    << offs
  }
  
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = []) {
    self.init( op:op, fn:fn, s:0, ri:ops[1].u16value, a:ops[0].u16value,  kind:kind )
  }
}

// Same as TypeZP, but for store ops
class TypeZP_s:TypeZP
{
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = []) {
    self.init( op:op, fn:fn, s:1, ri:ops[0].u16value, a:ops[1].u16value,  kind:kind )
  }
}


// Type M

class TypeM:InstWithImmediate
{
  init( op:UInt16, rk:UInt16, s:UInt16, ri:UInt16, a:UInt16, kind:ReferenceKind )
  {
    super.init(mask:0b1_1111, offs:0, kind:kind)
    let an = (rk-3) & 0b11   // This means an = 0 if rk is 7
    encoding |= (0b00)        << 14
    encoding |= (0b111 & op)  << 11
    encoding |= (0b111 & ri)  << 8
    encoding |= (0b11 & an)   << 6
    encoding |= (0b1 & s)     << 5
    encoding |= (mask & a)    << offs
  }
  
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = []) {
    self.init( op:op, rk:ops[0].u16value, s:0, ri:ops[2].u16value, a:ops[1].u16value,  kind:kind )
  }
}

// Same as TypeM, but for store ops
class TypeM_s:TypeM
{
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = []) {
    self.init( op:op, rk:ops[1].u16value, s:1, ri:ops[0].u16value, a:ops[2].u16value,  kind:kind )
  }
}

// Same as TypeM but for extended instructions with zero operands
class TypeM_ex0:TypeM
{
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = []) {
    self.init( op:op, rk:7, s:0, ri:0, a:0,  kind:kind )
  }
}

// Same as TypeM but for extended instructions with two operands
class TypeM_ex2:TypeM
{
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = []) {
    self.init( op:op, rk:7, s:0, ri:ops[1].u16value, a:ops[0].u16value,  kind:kind )
  }
}

// Type R

class TypeR:MachineInstr
{
  init( op:UInt16, fn:UInt16, ri:UInt16, rj:UInt16, rk:UInt16, kind:ReferenceKind )
  {
    super.init(kind)
    encoding |= (0b10)        << 14
    encoding |= (0b111 & op)  << 11
    encoding |= (0b111 & ri)  << 8
    encoding |= (0b11 & fn)   << 6
    encoding |= (0b111 & rj)  << 3
    encoding |= (0b111 & rk)  << 0
  }
  
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = []) {
    self.init( op:op, fn:fn, ri:ops[2].u16value, rj:ops[0].u16value, rk:ops[1].u16value, kind:kind)
  }
}

// Same as TypeR, but for the compare instructions
class TypeR_cmp:TypeR
{
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = []) {
    self.init( op:op, fn:fn, ri:ops[0].u16value, rj:ops[1].u16value, rk:ops[2].u16value, kind:kind)
  }
}

// Same as TypeR, but for 2 operand instructions using Rk
class TypeR_2k:TypeR
{
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = []) {
    self.init( op:op, fn:fn, ri:ops[1].u16value, rj:0, rk:ops[0].u16value, kind:kind)
  }
}

// Same as TypeR, but for 2 operand instructions using Rj
class TypeR_2j:TypeR
{
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = []) {
    self.init( op:op, fn:fn, ri:ops[1].u16value, rj:ops[0].u16value, rk:0, kind:kind)
  }
}

// Immediate value in program memory

class TypeK:InstWithImmediate
{
  init( k:UInt16, kind:ReferenceKind )
  {
    super.init(mask:0xffff, offs:0, kind:kind)
    encoding = k
  }

  required convenience init( op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = [] ) {
    self.init( k:ops[0].u16value, kind:kind ) }
}


//-------------------------------------------------------------------------------
// Machine instruction list
//-------------------------------------------------------------------------------

// Singleton class for creating MachineInst from Instruction
class MachineInstrList
{
  // Dictionary returning a unique MachineInstr type and opcode for a given Instruction
  static let allInstr:Dictionary<Instruction, (ty:MachineInstr.Type, kind:ReferenceKind, op:UInt16, fn:UInt16)> =
  [
    // Type Extended
    Instruction( "pfx".d,    [OpImm()] )                                        : (ty:TypeP.self,  kind:[], op:0b000, fn:0),
    Instruction( "pfx".d,    [OpSym()] )                                        : (ty:TypeP.self,  kind:[.absolute], op:0b000, fn:0),
    Instruction( "hlt".d,    [] )                                               : (ty:TypeM_ex0.self,  kind:[], op:0b001, fn:0),
    Instruction( "--0".d,    [] )                                               : (ty:TypeM_ex0.self,  kind:[], op:0b010, fn:0),
    Instruction( "lp".d,     [OpReg(.indirect), OpReg()] )                      : (ty:TypeM_ex2.self,  kind:[], op:0b011, fn:0),
    Instruction( "--1".d,    [] )                                               : (ty:TypeM_ex0.self,  kind:[], op:0b100, fn:0),
    Instruction( "--2".d,    [] )                                               : (ty:TypeM_ex0.self,  kind:[], op:0b101, fn:0),
    Instruction( "--3".d,    [] )                                               : (ty:TypeM_ex0.self,  kind:[], op:0b110, fn:0),
    Instruction( "--4".d,    [] )                                               : (ty:TypeM_ex0.self,  kind:[], op:0b111, fn:0),
  
    // Type M load
    
    Instruction( "--0".d,    [OpReg(.indirect), OpImm(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[], op:0b000, fn:0),
    Instruction( "--1".d,    [OpReg(.indirect), OpImm(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[], op:0b001, fn:0),
    Instruction( "cmp".d,    [OpReg(.indirect), OpImm(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[], op:0b010, fn:0),
    Instruction( "mov".d,    [OpReg(.indirect), OpImm(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[], op:0b011, fn:0),
    Instruction( "add".d,    [OpReg(.indirect), OpImm(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[], op:0b100, fn:0),
    Instruction( "sub".d,    [OpReg(.indirect), OpImm(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[], op:0b101, fn:0),
    Instruction( "and".d,    [OpReg(.indirect), OpImm(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[], op:0b110, fn:0),
    Instruction( "adt".d,    [OpReg(.indirect), OpImm(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[], op:0b111, fn:0),
    
    Instruction( "--0".d,    [OpReg(.indirect), OpSym(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[.absolute], op:0b000, fn:0),
    Instruction( "--1".d,    [OpReg(.indirect), OpSym(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[.absolute], op:0b001, fn:0),
    Instruction( "cmp".d,    [OpReg(.indirect), OpSym(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[.absolute], op:0b010, fn:0),
    Instruction( "mov".d,    [OpReg(.indirect), OpSym(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[.absolute], op:0b011, fn:0),
    Instruction( "add".d,    [OpReg(.indirect), OpSym(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[.absolute], op:0b100, fn:0),
    Instruction( "sub".d,    [OpReg(.indirect), OpSym(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[.absolute], op:0b101, fn:0),
    Instruction( "and".d,    [OpReg(.indirect), OpSym(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[.absolute], op:0b110, fn:0),
    Instruction( "adt".d,    [OpReg(.indirect), OpSym(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[.absolute], op:0b111, fn:0),
    
    // Type M store
    
    Instruction( "--0".d,    [OpReg(), OpReg(.indirect), OpImm(.indirect)] )    : (ty:TypeM_s.self,  kind:[], op:0b000, fn:0),
    Instruction( "--1".d,    [OpReg(), OpReg(.indirect), OpImm(.indirect)] )    : (ty:TypeM_s.self,  kind:[], op:0b001, fn:0),
    Instruction( "--2".d,    [OpReg(), OpReg(.indirect), OpImm(.indirect)] )    : (ty:TypeM_s.self,  kind:[], op:0b010, fn:0),
    Instruction( "mov".d,    [OpReg(), OpReg(.indirect), OpImm(.indirect)] )    : (ty:TypeM_s.self,  kind:[], op:0b011, fn:0),
    Instruction( "add".d,    [OpReg(), OpReg(.indirect), OpImm(.indirect)] )    : (ty:TypeM_s.self,  kind:[], op:0b100, fn:0),
    Instruction( "sub".d,    [OpReg(), OpReg(.indirect), OpImm(.indirect)] )    : (ty:TypeM_s.self,  kind:[], op:0b101, fn:0),
    Instruction( "and".d,    [OpReg(), OpReg(.indirect), OpImm(.indirect)] )    : (ty:TypeM_s.self,  kind:[], op:0b110, fn:0),
    Instruction( "adt".d,    [OpReg(), OpReg(.indirect), OpImm(.indirect)] )    : (ty:TypeM_s.self,  kind:[], op:0b111, fn:0),
    
    Instruction( "--0".d,    [OpReg(), OpReg(.indirect), OpSym(.indirect)] )    : (ty:TypeM_s.self,  kind:[.absolute], op:0b000, fn:0),
    Instruction( "--1".d,    [OpReg(), OpReg(.indirect), OpSym(.indirect)] )    : (ty:TypeM_s.self,  kind:[.absolute], op:0b001, fn:0),
    Instruction( "--2".d,    [OpReg(), OpReg(.indirect), OpSym(.indirect)] )    : (ty:TypeM_s.self,  kind:[.absolute], op:0b010, fn:0),
    Instruction( "mov".d,    [OpReg(), OpReg(.indirect), OpSym(.indirect)] )    : (ty:TypeM_s.self,  kind:[.absolute], op:0b011, fn:0),
    Instruction( "add".d,    [OpReg(), OpReg(.indirect), OpSym(.indirect)] )    : (ty:TypeM_s.self,  kind:[.absolute], op:0b100, fn:0),
    Instruction( "sub".d,    [OpReg(), OpReg(.indirect), OpSym(.indirect)] )    : (ty:TypeM_s.self,  kind:[.absolute], op:0b101, fn:0),
    Instruction( "and".d,    [OpReg(), OpReg(.indirect), OpSym(.indirect)] )    : (ty:TypeM_s.self,  kind:[.absolute], op:0b110, fn:0),
    Instruction( "adt".d,    [OpReg(), OpReg(.indirect), OpSym(.indirect)] )    : (ty:TypeM_s.self,  kind:[.absolute], op:0b111, fn:0),

    // Type ZP load
    
    Instruction( "--0".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b000, fn:0b00),
    Instruction( "--1".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b001, fn:0b00),
    Instruction( "cmp".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b010, fn:0b00),
    Instruction( "mov".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.immediate], op:0b011, fn:0b00),
    Instruction( "add".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b100, fn:0b00),
    Instruction( "sub".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b101, fn:0b00),
    Instruction( "and".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b110, fn:0b00),
    Instruction( "adt".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b111, fn:0b00),
    
    Instruction( "--2".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b000, fn:0b01),
    Instruction( "--3".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b001, fn:0b01),
    Instruction( "--4".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b010, fn:0b01),
    Instruction( "set".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b011, fn:0b01),
    Instruction( "dad".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b100, fn:0b01),
    Instruction( "rsb".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b101, fn:0b01),
    Instruction( "or".d,     [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b110, fn:0b01),
    Instruction( "adf".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b111, fn:0b01),
    
    Instruction( "--5".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b000, fn:0b10),
    Instruction( "--6".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b001, fn:0b10),
    Instruction( "cpc".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b010, fn:0b10),
    Instruction( "sef".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b011, fn:0b10),
    Instruction( "adc".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b100, fn:0b10),
    Instruction( "sbc".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b101, fn:0b10),
    Instruction( "xor".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b110, fn:0b10),
    Instruction( "sbt".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b111, fn:0b10),
    
    Instruction( "--7".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b000, fn:0b11),
    Instruction( "--8".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b001, fn:0b11),
    Instruction( "--9".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b010, fn:0b11),
    Instruction( "sel".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b011, fn:0b11),
    Instruction( "dac".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b100, fn:0b11),
    Instruction( "dsc".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b101, fn:0b11),
    Instruction( "mvl".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b110, fn:0b11),
    Instruction( "sbf".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b111, fn:0b11),
    
    Instruction( "--0".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b000, fn:0b00),
    Instruction( "--1".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b001, fn:0b00),
    Instruction( "cmp".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b010, fn:0b00),
    Instruction( "mov".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b011, fn:0b00),
    Instruction( "add".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b100, fn:0b00),
    Instruction( "sub".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b101, fn:0b00),
    Instruction( "and".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b110, fn:0b00),
    Instruction( "adt".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b111, fn:0b00),
    
    Instruction( "--2".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b000, fn:0b01),
    Instruction( "--3".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b001, fn:0b01),
    Instruction( "--4".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b010, fn:0b01),
    Instruction( "set".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b011, fn:0b01),
    Instruction( "dad".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b100, fn:0b01),
    Instruction( "rsb".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b101, fn:0b01),
    Instruction( "or".d,     [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b110, fn:0b01),
    Instruction( "adf".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b111, fn:0b01),
    
    Instruction( "--5".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b000, fn:0b10),
    Instruction( "--6".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b001, fn:0b10),
    Instruction( "cpc".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b010, fn:0b10),
    Instruction( "sef".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b011, fn:0b10),
    Instruction( "adc".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b100, fn:0b10),
    Instruction( "sbc".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b101, fn:0b10),
    Instruction( "xor".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b110, fn:0b10),
    Instruction( "sbt".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b111, fn:0b10),
    
    Instruction( "--7".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b000, fn:0b11),
    Instruction( "--8".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b001, fn:0b11),
    Instruction( "--9".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b010, fn:0b11),
    Instruction( "sel".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b011, fn:0b11),
    Instruction( "dac".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b100, fn:0b11),
    Instruction( "dsc".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b101, fn:0b11),
    Instruction( "mvl".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b110, fn:0b11),
    Instruction( "sbf".d,    [OpSym(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[.absolute], op:0b111, fn:0b11),
    
    // Type ZP store
    
    Instruction( "--0".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b000, fn:0b00),
    Instruction( "--1".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b001, fn:0b00),
    Instruction( "--2".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b010, fn:0b00),
    Instruction( "mov".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.immediate], op:0b011, fn:0b00),
    Instruction( "add".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b100, fn:0b00),
    Instruction( "sub".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b101, fn:0b00),
    Instruction( "and".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b110, fn:0b00),
    Instruction( "adt".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b111, fn:0b00),
    
    Instruction( "--3".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b000, fn:0b01),
    Instruction( "--4".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b001, fn:0b01),
    Instruction( "--5".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b010, fn:0b01),
    Instruction( "set".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b011, fn:0b01),
    Instruction( "dad".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b100, fn:0b01),
    Instruction( "rsb".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b101, fn:0b01),
    Instruction( "or".d,     [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b110, fn:0b01),
    Instruction( "adf".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b111, fn:0b01),
    
    Instruction( "--6".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b000, fn:0b10),
    Instruction( "--7".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b001, fn:0b10),
    Instruction( "--8".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b010, fn:0b10),
    Instruction( "sef".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b011, fn:0b10),
    Instruction( "adc".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b100, fn:0b10),
    Instruction( "sbc".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b101, fn:0b10),
    Instruction( "xor".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b110, fn:0b10),
    Instruction( "sbt".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b111, fn:0b10),
    
    Instruction( "--9".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b000, fn:0b11),
    Instruction( "--A".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b001, fn:0b11),
    Instruction( "--B".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b010, fn:0b11),
    Instruction( "sel".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b011, fn:0b11),
    Instruction( "dac".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b100, fn:0b11),
    Instruction( "dsc".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b101, fn:0b11),
    Instruction( "mvl".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b110, fn:0b11),
    Instruction( "sbf".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b111, fn:0b11),
 
    Instruction( "--0".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b000, fn:0b00),
    Instruction( "--1".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b001, fn:0b00),
    Instruction( "--2".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b010, fn:0b00),
    Instruction( "mov".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b011, fn:0b00),
    Instruction( "add".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b100, fn:0b00),
    Instruction( "sub".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b101, fn:0b00),
    Instruction( "and".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b110, fn:0b00),
    Instruction( "adt".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b111, fn:0b00),
    
    Instruction( "--3".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b000, fn:0b01),
    Instruction( "--4".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b001, fn:0b01),
    Instruction( "--5".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b010, fn:0b01),
    Instruction( "set".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b011, fn:0b01),
    Instruction( "dad".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b100, fn:0b01),
    Instruction( "rsb".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b101, fn:0b01),
    Instruction( "or".d,     [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b110, fn:0b01),
    Instruction( "adf".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b111, fn:0b01),
    
    Instruction( "--6".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b000, fn:0b10),
    Instruction( "--7".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b001, fn:0b10),
    Instruction( "--8".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b010, fn:0b10),
    Instruction( "sef".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b011, fn:0b10),
    Instruction( "adc".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b100, fn:0b10),
    Instruction( "sbc".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b101, fn:0b10),
    Instruction( "xor".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b110, fn:0b10),
    Instruction( "sbt".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b111, fn:0b10),
    
    Instruction( "--9".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b000, fn:0b11),
    Instruction( "--A".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b001, fn:0b11),
    Instruction( "--B".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b010, fn:0b11),
    Instruction( "sel".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b011, fn:0b11),
    Instruction( "dac".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b100, fn:0b11),
    Instruction( "dsc".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b101, fn:0b11),
    Instruction( "mvl".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b110, fn:0b11),
    Instruction( "sbf".d,    [OpReg(), OpSym(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[.absolute], op:0b111, fn:0b11),
    
 // Type R
    
    Instruction( "sr1".d,    [OpReg(), OpReg()] )                               : (ty:TypeR_2j.self,  kind:[], op:0b000, fn:0b00),
    Instruction( "sl1".d,    [OpReg(), OpReg()] )                               : (ty:TypeR_2j.self,  kind:[], op:0b001, fn:0b00),
    Instruction( "cmp".d,    [OpCC(), OpReg(), OpReg()] )                       : (ty:TypeR_cmp.self,  kind:[], op:0b010, fn:0b00),
    Instruction( "mov".d,    [OpReg(), OpReg()] )                               : (ty:TypeR_2k.self,  kind:[], op:0b011, fn:0b00),
    Instruction( "add".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b100, fn:0b00),
    Instruction( "sub".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b101, fn:0b00),
    Instruction( "and".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b110, fn:0b00),
    Instruction( "adt".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b111, fn:0b00),
    
    Instruction( "rr1".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b000, fn:0b01),
    Instruction( "rl1".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b001, fn:0b01),
    Instruction( "--0".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b010, fn:0b01),
    Instruction( "set".d,    [OpReg(), OpReg()] )                               : (ty:TypeR_2k.self,  kind:[], op:0b011, fn:0b01),
    Instruction( "dad".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b100, fn:0b01),
    Instruction( "rsb".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b101, fn:0b01),
    Instruction( "or".d,     [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b110, fn:0b01),
    Instruction( "adf".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b111, fn:0b01),
    
    Instruction( "sr4".d,    [OpReg(), OpReg()] )                               : (ty:TypeR_2j.self,  kind:[], op:0b000, fn:0b10),
    Instruction( "sl4".d,    [OpReg(), OpReg()] )                               : (ty:TypeR_2j.self,  kind:[], op:0b001, fn:0b10),
    Instruction( "cpc".d,    [OpCC(), OpReg(), OpReg()] )                       : (ty:TypeR_cmp.self,  kind:[], op:0b010, fn:0b10),
    Instruction( "sef".d,    [OpReg(), OpReg()] )                               : (ty:TypeR_2k.self,  kind:[], op:0b011, fn:0b10),
    Instruction( "adc".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b100, fn:0b10),
    Instruction( "sbc".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b101, fn:0b10),
    Instruction( "xor".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b110, fn:0b10),
    Instruction( "sbt".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b111, fn:0b10),
    
    Instruction( "rr4".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b000, fn:0b11),
    Instruction( "rl4".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b001, fn:0b11),
    Instruction( "--1".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b010, fn:0b11),
    Instruction( "sel".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b011, fn:0b11),
    Instruction( "dac".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b100, fn:0b11),
    Instruction( "dsc".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b101, fn:0b11),
    Instruction( "mvl".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b110, fn:0b11),
    Instruction( "sbf".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b111, fn:0b11),
 
    // Type I
    
    Instruction( "--0".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b000, fn:0b00),
    Instruction( "--1".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b001, fn:0b00),
    Instruction( "cmp".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b010, fn:0b00),
    Instruction( "mov".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b011, fn:0b00),
    Instruction( "add".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b100, fn:0b00),
    Instruction( "sub".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b101, fn:0b00),
    Instruction( "and".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b110, fn:0b00),
    Instruction( "adt".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b111, fn:0b00),
    
    Instruction( "--2".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b000, fn:0b01),
    Instruction( "--3".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b001, fn:0b01),
    Instruction( "--4".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b010, fn:0b01),
    Instruction( "set".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b011, fn:0b01),
    Instruction( "dad".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b100, fn:0b01),
    Instruction( "rsb".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b101, fn:0b01),
    Instruction( "or".d,     [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b110, fn:0b01),
    Instruction( "adf".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b111, fn:0b01),
    
    Instruction( "--5".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b000, fn:0b10),
    Instruction( "--6".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b001, fn:0b10),
    Instruction( "cpc".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b010, fn:0b10),
    Instruction( "sef".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b011, fn:0b10),
    Instruction( "adc".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b100, fn:0b10),
    Instruction( "sbc".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b101, fn:0b10),
    Instruction( "xor".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b110, fn:0b10),
    Instruction( "sbt".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b111, fn:0b10),
    
    Instruction( "--7".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b000, fn:0b11),
    Instruction( "--8".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b001, fn:0b11),
    Instruction( "--9".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b010, fn:0b11),
    Instruction( "sel".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b011, fn:0b11),
    Instruction( "dac".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b100, fn:0b11),
    Instruction( "dsc".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b101, fn:0b11),
    Instruction( "mvl".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b110, fn:0b11),
    Instruction( "sbf".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b111, fn:0b11),
    
    Instruction( "--0".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b000, fn:0b00),
    Instruction( "--1".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b001, fn:0b00),
    Instruction( "cmp".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b010, fn:0b00),
    Instruction( "mov".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b011, fn:0b00),
    Instruction( "add".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b100, fn:0b00),
    Instruction( "sub".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b101, fn:0b00),
    Instruction( "and".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b110, fn:0b00),
    Instruction( "adt".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b111, fn:0b00),
    
    Instruction( "--2".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b000, fn:0b01),
    Instruction( "--3".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b001, fn:0b01),
    Instruction( "--4".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b010, fn:0b01),
    Instruction( "set".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b011, fn:0b01),
    Instruction( "dad".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b100, fn:0b01),
    Instruction( "rsb".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b101, fn:0b01),
    Instruction( "or".d,     [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b110, fn:0b01),
    Instruction( "adf".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b111, fn:0b01),
    
    Instruction( "--5".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b000, fn:0b10),
    Instruction( "--6".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b001, fn:0b10),
    Instruction( "cpc".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b010, fn:0b10),
    Instruction( "sef".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b011, fn:0b10),
    Instruction( "adc".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b100, fn:0b10),
    Instruction( "sbc".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b101, fn:0b10),
    Instruction( "xor".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b110, fn:0b10),
    Instruction( "sbt".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b111, fn:0b10),
    
    Instruction( "--7".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b000, fn:0b11),
    Instruction( "--8".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b001, fn:0b11),
    Instruction( "--9".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b010, fn:0b11),
    Instruction( "sel".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b011, fn:0b11),
    Instruction( "dac".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b100, fn:0b11),
    Instruction( "dsc".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b101, fn:0b11),
    Instruction( "mvl".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b110, fn:0b11),
    Instruction( "sbf".d,    [OpSym(), OpReg()] )                               : (ty:TypeI.self,  kind:[.absolute], op:0b111, fn:0b11),
    
    // Type J
    
    Instruction( "j".d,      [OpSym()] )                                        : (ty:TypeJ.self,  kind:[.absolute], op:0b011, fn:0b00),
    Instruction( "b".d,      [OpSym()] )                                        : (ty:TypeJ.self,  kind:[.relative], op:0b100, fn:0b00),
    Instruction( "bt".d,     [OpSym()] )                                        : (ty:TypeJ.self,  kind:[.relative], op:0b111, fn:0b00),
    Instruction( "bf".d,     [OpSym()] )                                        : (ty:TypeJ.self,  kind:[.relative], op:0b111, fn:0b01),
    Instruction( "jl".d,     [OpSym()] )                                        : (ty:TypeJ.self,  kind:[.absolute], op:0b110, fn:0b11),

    // The following represent immediate words
    
    Instruction( "_imm".d,   [OpImm()] )                                        : (ty:TypeK.self,   kind:[], op:0, fn:0),
    Instruction( "_imm".d,   [OpSym()] )                                        : (ty:TypeK.self,   kind:.absolute, op:0, fn:0),
  ]

  // Returs a new MachineInstr object initialized with a matching Instruction
  static func newMachineInst( _ inst:Instruction ) -> MachineInstr?
  {
    if let t = allInstr[inst]
    {
      let machineInst = t.ty.init(op:t.op, fn:t.fn, ops:inst.ops, kind:t.kind)
      return machineInst
    }
//    else if let opReg = inst.opSP
//    {
//      opReg.opt.remove(.isSP)
//      return newMachineInst( inst )
//    }

    return nil
  }
}

//-------------------------------------------------------------------------------
// Machine data types and formats
//-------------------------------------------------------------------------------

// Base class to represent machine data values. Simple type objects keep two
// convenience representations of the same value as an Int value and raw Data bytes.
// Large type objects such as strings only use the raw Data bytes property.
class MachineData
{
  var bytes = Data()
  var value:Int?
  
  // Update both properties from an Int value of a given size
  func setBytes( size:Int, value k:Int )
  {
    value = k
    bytes.removeAll(keepingCapacity:true)
    var val = value!
    for _ in 0..<size
    {
      let byte = UInt8(truncatingIfNeeded:(val & 0xff))
      bytes.append(byte)  // appends in little endian way
      val = val >> 8
    }
  }

  // Designated initializer
  init( size:Int, value k:Int )
  {
    setBytes(size:size, value:k)
  }
  
  // Designated initializer
  init( data:Data )
  {
    value = nil
    bytes = data   // appends as provided
  }
  
  // Conveninence initializer that must be implemented by subclases
  required convenience init( size:Int, op:Operand )
  {
    self.init( size:2, value:0 )
  }
}

// Immediate value, a.k.a constant
class TypeImm:MachineData
{
  required convenience init( size:Int, op:Operand ) {
    self.init( size:size, value:Int(op.u16value) )
  }
}

// Sequence of bytes represented as a string
class TypeString:MachineData
{
  required convenience init( size:Int, op:Operand ) {
    self.init( data:op.sym! )
  }
}

// Absolute address
class TypeAddr:MachineData /*, InstDTAbsolute*/
{
  required convenience init( size:Int, op:Operand ) {
    self.init( size:size, value:Int(op.u16value) )
  }
  
  func setAbsolute( a:UInt16 ) {
    setBytes(size:2, value:Int(a))
  }
  
  func setPrefixedValue( a:UInt16 ) {
    setAbsolute( a: a )
  }
}

//-------------------------------------------------------------------------------
// Machine data list
//-------------------------------------------------------------------------------

// Singleton class for creating MachineData from DataValue
class MachineDataList
{
  // Dictionary returning a unique DataValue type for a given MachineData object
  static let allData:Dictionary<DataValue, MachineData.Type> =
  [
    DataValue( 0, OpImm() )    : TypeImm.self,
    DataValue( 0, OpStr() )    : TypeString.self,
    DataValue( 0, OpSym() )    : TypeAddr.self
  ]
  
  // Returs a new MachineData object initialized with a matching DataValue
  static func newMachineData( _ dv:DataValue ) -> MachineData?
  {
    if let machineDataType = allData[dv]
    {
      let machineData = machineDataType.init( size:dv.byteSize, op:dv.oper )
      return machineData
    }
    return nil
  }
}
