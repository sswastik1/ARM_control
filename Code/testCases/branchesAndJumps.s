branch1:
    slli    t0, t0, 31
    slli    t0, t0, 1
    
    addi    t0, t0, 2
    jalr    x0, a0, 0
    beq     t0, a0, branch1
    bge     t0, a1, branch2
    addi    t0, t0, -5
    jalr    x0, a0, 0
branch2:
    beq     a0, a1, branch1
    jalr    x0, s4, 0
    