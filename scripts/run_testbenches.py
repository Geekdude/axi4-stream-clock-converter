#!/usr/bin/env python3

"""Script used to easily run testbenches using GHDL."""

import argparse
import sys
import os
import datetime
import subprocess
import time
import functools
import random
import re
from multiprocessing import Pool
from subprocess import check_output


def list_all(d):
    d = os.path.realpath(d)
    return [os.path.join(d, i) for i in os.listdir(d)]


def list_files(d):
    'return directory listing with full path names of files only'
    return [f for f in list_all(d) if os.path.isfile(f)]


def list_dirs(d):
    'return directory listing with full path names of folders only'
    return [f for f in list_all(d) if os.path.isdir(f)]


def run(command):
    print(command)
    out = check_output(command, shell=True).decode()

    if out:
        print(out)


def import_src():
    run('ghdl -a --ieee=synopsys --std=08 src/*')


def run_test(tb_file, vcd):
    entname = os.path.splitext(os.path.basename(tb_file))[0]
    vcdflag = '--vcd={}.vcd'.format(entname) if vcd else ''
    run('ghdl -a --ieee=synopsys --std=08 {}'.format(tb_file))
    run('ghdl -e --ieee=synopsys --std=08 {}'.format(entname))
    run('ghdl -r --ieee=synopsys --std=08 {} {} --assert-level=error --ieee-asserts=disable-at-0'.format(entname, vcdflag))


def main(argv):
    # Parse the arguments
    parser = argparse.ArgumentParser(description="""Script used to easily run testbenches using GHDL.""")
    parser.add_argument('-t', '--test', type=str, help="testbench file to run or 'all'", required=True)
    parser.add_argument('-v', '--vcd', action="store_true", help="save VCD wave file")

    args = parser.parse_args(argv[1:])

    import_src()

    if args.test == 'all':
        files = list_files('testbench')

        for f in files:
            match = re.match('^.*/(.*_tb).vhd', f)
            if match:
                run_test(f, args.vcd)

    else:
        run_test(args.test, args.vcd)


if __name__ == '__main__':
    main(sys.argv)
