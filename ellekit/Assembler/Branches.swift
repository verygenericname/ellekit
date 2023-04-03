
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © Charlotte Belanger

public func disassembleBranchImm(_ opcode: UInt64) -> Int {
    var imm = (opcode & 0x3FFFFFF) << 2
    if (opcode & 0x2000000) == 1 {
        // Sign extend
        imm |= 0xFC000000
    }
    return Int(imm)
}

func redirectBranch(_ target: UnsafeMutableRawPointer, _ isn: UInt64, _ ptr: UnsafeMutableRawPointer) -> [UInt8] {
    let pcRel = disassembleBranchImm(reverse(isn))

    let originalTarget = UInt64(UInt(bitPattern: target)) + UInt64(pcRel)

    let code = assembleJump(originalTarget, pc: UInt64(UInt(bitPattern: target)), link: false, big: true)

    return code
}

// PAC: strip before calling this function
func calculateOffset(_ target: UnsafeMutableRawPointer, _ replacement: UnsafeMutableRawPointer) -> Int {
    let sign = target > replacement ? -1 : 1
    let offsetAbs = abs((Int(UInt(bitPattern: replacement)) - Int(UInt(bitPattern: target)))) / 4
    return offsetAbs * sign
}

public class b: Instruction {
    required public init(encoded: Int) {
        self.value = encoded
    }

    public func bytes() -> [UInt8] {
        byteArray(from: value)
    }

    let value: Int

    public init(_ addr: Int) {
        var base = Self.base
        base |= (addr & 0x3ffffff)
        self.value = reverse(base)
    }

    static let base = 0b0_00101_00000000000000000000000000
}

public class bl: Instruction {
    required public init(encoded: Int) {
        self.value = encoded
    }

    public func bytes() -> [UInt8] {
        byteArray(from: value)
    }

    let value: Int

    public init(_ addr: Int) {
        var base = Self.base
        base |= addr
        self.value = reverse(base)
    }

    static let base = 0b1_00101_00000000000000000000000000
}

public class blr: Instruction {
    required public init(encoded: Int) {
        self.value = encoded
    }

    public func bytes() -> [UInt8] {
        byteArray(from: value)
    }

    let value: Int

    public init(_ register: Register) {
        var base = Self.base
        base |= (register.value << 5)
        self.value = reverse(base)
    }

    static let base = 0b1101011_0_0_01_11111_0000_0_0_00000_00000
}

public class br: Instruction {
    required public init(encoded: Int) {
        self.value = encoded
    }

    public func bytes() -> [UInt8] {
        byteArray(from: value)
    }

    let value: Int

    public init(_ register: Register) {
        var base = Self.base
        base |= register.value << 5
        self.value = reverse(base)
    }

    static let base = 0b1101011_0_0_00_11111_0000_0_0_00000_00000
}

public class cbz: Instruction {
    required public init(encoded: Int) {
        self.value = encoded
    }

    public func bytes() -> [UInt8] {
        byteArray(from: value)
    }

    let value: Int

    public init(_ register: Register, _ addr: Int) {
        var base = Self.base
        base |= (register.w ? 0 : 1) << 31
        base |= (addr << 5)
        base |= register.value
        self.value = reverse(base)
    }

    static let base = 0b0_011010_0_0000000000000000000_00000
}

public class cbnz: Instruction {
    required public init(encoded: Int) {
        self.value = encoded
    }

    public func bytes() -> [UInt8] {
        byteArray(from: value)
    }

    let value: Int

    public init(_ register: Register, _ addr: Int) {
        var base = Self.base
        base |= (register.w ? 0 : 1) << 31
        base |= (addr << 5)
        base |= register.value
        self.value = reverse(base)
    }

    static let base = 0b0_011010_1_0000000000000000000_00000
    
    public static func destination(_ instruction: UInt32, pc: UInt64) -> UInt64 {
        var imm = (instruction & 0xFFFFE0) >> 3
        imm |= (instruction & 0x60000000) >> 29
        return pc + UInt64((imm - 1) / 4)
    }
}

func assembleJump(_ target: UInt64, pc: UInt64, size: Int = 5, link: Bool, big: Bool = false) -> [UInt8] {
    let offset = Int(target - pc)
    if (size > 5 && abs(offset / 1024 / 1024) > 128) || big {
        let target_addr = Int(UInt64(offset) + pc)
        let codeBuild = [
            movk(.x16, target_addr % 65536).bytes(),
            movk(.x16, (target_addr / 65536) % 65536, lsl: 16).bytes(),
            movk(.x16, ((target_addr / 65536) / 65536) % 65536, lsl: 32).bytes(),
            movk(.x16, ((target_addr / 65536) / 65536) / 65536, lsl: 48).bytes(),
            link ? blr(.x16).bytes() : br(.x16).bytes()
        ]
        return codeBuild.joined().literal()
    } else {
        let codeBuild = [
            link ? bl(offset).bytes() : b(offset).bytes()
        ]
        return codeBuild.joined().literal()
    }
}

func assembleReference(target: UInt64, register: Int) -> [UInt8] {
    let codeBuild = [
        movk(.x(register), target % 65536).bytes(),
        movk(.x(register), (target / 65536) % 65536, lsl: 16).bytes(),
        movk(.x(register), ((target / 65536) / 65536) % 65536, lsl: 32).bytes(),
        movk(.x(register), ((target / 65536) / 65536) / 65536, lsl: 48).bytes(),
    ]
    return codeBuild.joined().literal()
}
