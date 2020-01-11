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
  static let relative = ReferenceKind(rawValue: 1 << 1)      // Indirect memory addressing
  static let absolute = ReferenceKind(rawValue: 1 << 2)      // Indirect program addressing
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
    // Might be overrided to test sign extended immediates
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
    encoding |= (0b11) << 14
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
    let ak = rk - 4 ;
    encoding |= (0b00)        << 14
    encoding |= (0b111 & op)  << 11
    encoding |= (0b111 & ri)  << 8
    encoding |= (0b11 & ak)   << 6
    encoding |= (0b1 & s)     << 5
    encoding |= (mask & a)    << offs
  }
  
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = []) {
    self.init( op:op, rk:ops[0].u16value, s:0, ri:ops[2].u16value, a:ops[1].u16value,  kind:kind )
  }
}

// Same as TypeZP, but for store ops
class TypeM_s:TypeM
{
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = []) {
    self.init( op:op, rk:ops[1].u16value, s:0, ri:ops[0].u16value, a:ops[2].u16value,  kind:kind )
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

// Same as TypeR, but for 2 operand instructions
class TypeR_2:TypeR
{
  required convenience init(op:UInt16, fn:UInt16, ops:[Operand], kind:ReferenceKind = []) {
    self.init( op:op, fn:fn, ri:ops[1].u16value, rj:0, rk:ops[0].u16value, kind:kind)
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
    // Type M load
    
    Instruction( "cmp".d,    [OpReg(.indirect), OpImm(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[], op:0b000, fn:0),
    Instruction( "mov".d,    [OpReg(.indirect), OpImm(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[], op:0b001, fn:0),
    Instruction( "add".d,    [OpReg(.indirect), OpImm(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[], op:0b010, fn:0),
    Instruction( "sub".d,    [OpReg(.indirect), OpImm(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[], op:0b011, fn:0),
    Instruction( "and".d,    [OpReg(.indirect), OpImm(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[], op:0b100, fn:0),
    Instruction( "---".d,    [OpReg(.indirect), OpImm(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[], op:0b101, fn:0),
    Instruction( "---".d,    [OpReg(.indirect), OpImm(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[], op:0b011, fn:0),
    Instruction( "adt".d,    [OpReg(.indirect), OpImm(.indirect), OpReg()] )    : (ty:TypeM.self,  kind:[], op:0b111, fn:0),
    
    // Type M store
    
    Instruction( "---".d,    [OpReg(), OpReg(.indirect), OpImm(.indirect)] )    : (ty:TypeM_s.self,  kind:[], op:0b000, fn:0),
    Instruction( "mov".d,    [OpReg(), OpReg(.indirect), OpImm(.indirect)] )    : (ty:TypeM_s.self,  kind:[], op:0b001, fn:0),
    Instruction( "add".d,    [OpReg(), OpReg(.indirect), OpImm(.indirect)] )    : (ty:TypeM_s.self,  kind:[], op:0b010, fn:0),
    Instruction( "sub".d,    [OpReg(), OpReg(.indirect), OpImm(.indirect)] )    : (ty:TypeM_s.self,  kind:[], op:0b011, fn:0),
    Instruction( "and".d,    [OpReg(), OpReg(.indirect), OpImm(.indirect)] )    : (ty:TypeM_s.self,  kind:[], op:0b100, fn:0),
    Instruction( "---".d,    [OpReg(), OpReg(.indirect), OpImm(.indirect)] )    : (ty:TypeM_s.self,  kind:[], op:0b101, fn:0),
    Instruction( "---".d,    [OpReg(), OpReg(.indirect), OpImm(.indirect)] )    : (ty:TypeM_s.self,  kind:[], op:0b011, fn:0),
    Instruction( "adt".d,    [OpReg(), OpReg(.indirect), OpImm(.indirect)] )    : (ty:TypeM_s.self,  kind:[], op:0b111, fn:0),

    // Type ZP load
    
    Instruction( "cmp".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b000, fn:0b00),
    Instruction( "mov".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b001, fn:0b00),
    Instruction( "add".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b010, fn:0b00),
    Instruction( "sub".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b011, fn:0b00),
    Instruction( "and".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b100, fn:0b00),
    Instruction( "---".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b101, fn:0b00),
    Instruction( "---".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b011, fn:0b00),
    Instruction( "adt".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b111, fn:0b00),
    
    Instruction( "---".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b000, fn:0b01),
    Instruction( "set".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b001, fn:0b01),
    Instruction( "dad".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b010, fn:0b01),
    Instruction( "rsb".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b011, fn:0b01),
    Instruction( "or".d,     [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b100, fn:0b01),
    Instruction( "---".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b101, fn:0b01),
    Instruction( "---".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b011, fn:0b01),
    Instruction( "adf".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b111, fn:0b01),
    
    Instruction( "cpc".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b000, fn:0b10),
    Instruction( "sef".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b001, fn:0b10),
    Instruction( "adc".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b010, fn:0b10),
    Instruction( "sbc".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b011, fn:0b10),
    Instruction( "xor".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b100, fn:0b10),
    Instruction( "---".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b101, fn:0b10),
    Instruction( "---".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b011, fn:0b10),
    Instruction( "sbt".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b111, fn:0b10),
    
    Instruction( "---".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b000, fn:0b11),
    Instruction( "sel".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b001, fn:0b11),
    Instruction( "dac".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b010, fn:0b11),
    Instruction( "dsc".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b011, fn:0b11),
    Instruction( "mvl".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b100, fn:0b11),
    Instruction( "---".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b101, fn:0b11),
    Instruction( "---".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b011, fn:0b11),
    Instruction( "sbf".d,    [OpImm(.indirect), OpReg()] )                      : (ty:TypeZP.self,  kind:[], op:0b111, fn:0b11),
    
    // Type ZP store
    
    Instruction( "---".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b000, fn:0b00),
    Instruction( "mov".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b001, fn:0b00),
    Instruction( "add".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b010, fn:0b00),
    Instruction( "sub".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b011, fn:0b00),
    Instruction( "and".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b100, fn:0b00),
    Instruction( "---".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b101, fn:0b00),
    Instruction( "---".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b011, fn:0b00),
    Instruction( "adt".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b111, fn:0b00),
    
    Instruction( "---".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b000, fn:0b01),
    Instruction( "set".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b001, fn:0b01),
    Instruction( "dad".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b010, fn:0b01),
    Instruction( "rsb".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b011, fn:0b01),
    Instruction( "or".d,     [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b100, fn:0b01),
    Instruction( "---".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b101, fn:0b01),
    Instruction( "---".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b011, fn:0b01),
    Instruction( "adf".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b111, fn:0b01),
    
    Instruction( "---".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b000, fn:0b10),
    Instruction( "sef".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b001, fn:0b10),
    Instruction( "adc".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b010, fn:0b10),
    Instruction( "sbc".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b011, fn:0b10),
    Instruction( "xor".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b100, fn:0b10),
    Instruction( "---".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b101, fn:0b10),
    Instruction( "---".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b011, fn:0b10),
    Instruction( "sbt".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b111, fn:0b10),
    
    Instruction( "---".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b000, fn:0b11),
    Instruction( "sel".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b001, fn:0b11),
    Instruction( "dac".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b010, fn:0b11),
    Instruction( "dsc".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b011, fn:0b11),
    Instruction( "mvl".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b100, fn:0b11),
    Instruction( "---".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b101, fn:0b11),
    Instruction( "---".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b011, fn:0b11),
    Instruction( "sbf".d,    [OpReg(), OpImm(.indirect)] )                      : (ty:TypeZP_s.self,  kind:[], op:0b111, fn:0b11),
 
 // Type R
    
    Instruction( "cmp".d,    [OpCC(), OpReg(), OpReg()] )                       : (ty:TypeR_cmp.self,  kind:[], op:0b000, fn:0b00),
    Instruction( "mov".d,    [OpReg(), OpReg()] )                               : (ty:TypeR_2.self,  kind:[], op:0b001, fn:0b00),
    Instruction( "add".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b010, fn:0b00),
    Instruction( "sub".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b011, fn:0b00),
    Instruction( "and".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b100, fn:0b00),
    Instruction( "sr1".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b101, fn:0b00),
    Instruction( "sl1".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b011, fn:0b00),
    Instruction( "adt".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b111, fn:0b00),
    
    Instruction( "---".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b000, fn:0b01),
    Instruction( "set".d,    [OpReg(), OpReg()] )                               : (ty:TypeR_2.self,  kind:[], op:0b001, fn:0b01),
    Instruction( "dad".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b010, fn:0b01),
    Instruction( "rsb".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b011, fn:0b01),
    Instruction( "or".d,     [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b100, fn:0b01),
    Instruction( "rr1".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b101, fn:0b01),
    Instruction( "rl1".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b011, fn:0b01),
    Instruction( "adf".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b111, fn:0b01),
    
    Instruction( "cpc".d,    [OpCC(), OpReg(), OpReg()] )                       : (ty:TypeR_cmp.self,  kind:[], op:0b000, fn:0b10),
    Instruction( "sef".d,    [OpReg(), OpReg()] )                               : (ty:TypeR_2.self,  kind:[], op:0b001, fn:0b10),
    Instruction( "adc".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b010, fn:0b10),
    Instruction( "sbc".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b011, fn:0b10),
    Instruction( "xor".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b100, fn:0b10),
    Instruction( "sr4".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b101, fn:0b10),
    Instruction( "sl4".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b011, fn:0b10),
    Instruction( "sbt".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b111, fn:0b10),
    
    Instruction( "---".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b000, fn:0b11),
    Instruction( "sel".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b001, fn:0b11),
    Instruction( "dac".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b010, fn:0b11),
    Instruction( "dsc".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b011, fn:0b11),
    Instruction( "mvl".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b100, fn:0b11),
    Instruction( "rr4".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b101, fn:0b11),
    Instruction( "rl4".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b011, fn:0b11),
    Instruction( "sbf".d,    [OpReg(), OpReg(), OpReg()] )                      : (ty:TypeR.self,  kind:[], op:0b111, fn:0b11),
 
    // Type I
    
    Instruction( "cmp".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b000, fn:0b00),
    Instruction( "mov".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b001, fn:0b00),
    Instruction( "add".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b010, fn:0b00),
    Instruction( "sub".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b011, fn:0b00),
    Instruction( "and".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b100, fn:0b00),
    Instruction( "---".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b101, fn:0b00),
    Instruction( "---".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b011, fn:0b00),
    Instruction( "adt".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b111, fn:0b00),
    
    Instruction( "pfx".d,    [OpImm()] )                                        : (ty:TypeP.self,  kind:[], op:0b000, fn:0b01),
    Instruction( "set".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b001, fn:0b01),
    Instruction( "dad".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b010, fn:0b01),
    Instruction( "rsb".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b011, fn:0b01),
    Instruction( "or".d,     [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b100, fn:0b01),
    Instruction( "---".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b101, fn:0b01),
    Instruction( "---".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b011, fn:0b01),
    Instruction( "adf".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b111, fn:0b01),
    
    Instruction( "cpc".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b000, fn:0b10),
    Instruction( "sef".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b001, fn:0b10),
    Instruction( "adc".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b010, fn:0b10),
    Instruction( "sbc".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b011, fn:0b10),
    Instruction( "xor".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b100, fn:0b10),
    Instruction( "---".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b101, fn:0b10),
    Instruction( "---".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b011, fn:0b10),
    Instruction( "sbt".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b111, fn:0b10),
    
    Instruction( "hlt".d,    [] )                                               : (ty:TypeI_0.self,  kind:[], op:0b000, fn:0b11),
    Instruction( "sel".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b001, fn:0b11),
    Instruction( "dac".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b010, fn:0b11),
    Instruction( "dsc".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b011, fn:0b11),
    Instruction( "mvl".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b100, fn:0b11),
    Instruction( "---".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b101, fn:0b11),
    Instruction( "---".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b011, fn:0b11),
    Instruction( "sbf".d,    [OpImm(), OpReg()] )                               : (ty:TypeI.self,  kind:[], op:0b111, fn:0b11),
    
    // The following represent immediate words
    Instruction( "_imm".d,   [OpImm()] )                       : (ty:TypeK.self,   kind:[], op:0, fn:0),
    Instruction( "_imm".d,   [OpSym()] )                       : (ty:TypeK.self,   kind:.absolute, op:0, fn:0),
  ]
  
  
  TO DO posar les instruccions tipus J el prefix tipus J
  

  // Returs a new MachineInstr object initialized with a matching Instruction
  static func newMachineInst( _ inst:Instruction ) -> MachineInstr?
  {
    if let t = allInstr[inst]
    {
      let machineInst = t.ty.init(op:t.op, ops:inst.ops, rk:t.rk)
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
