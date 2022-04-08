branch1:
    addi    t0, a0, 2
    beq     t0, a1, branch2
    jalr    x0, a2, 0
branch2:
    jalr    x0, s3, 0
    beq     t0, s4, branch1