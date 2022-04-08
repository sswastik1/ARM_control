    beq   t0, s1, branch3
    beq   a0, a1, branch1
branch1:
    bge   s0, a0, branch2
    beq   t0, t1, branch1
branch2:
    beq   a0, s3, branch1
    bge   a0, s4, branch3
    bge   a1, s3, branch3
branch3:
    addi  a0, a0, 1