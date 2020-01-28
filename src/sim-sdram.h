// Copyright 2020, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

void sim_sdram_init(void);
int sim_sdram(unsigned ctl, unsigned addr, unsigned din, unsigned* dout);
