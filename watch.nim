# Copyright 2015-2017 Yoshihiro Tanaka
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

  # http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Author: Yoshihiro Tanaka <contact@cordea.jp>
# date  : 2015-12-05

import os, osproc
import times, strutils
import parseopt2
import threadpool
import math
import ncurses

type
    window = ref winParam
    winParam = object
        x: int
        y: int

var
    win: window

proc handleControlC() {.noconv.} =
    echo "exit"
    quit 0

proc getScreenSize(): window =
    var
        x, y: int
        win: window
    new win
    getmaxyx(initscr(), y, x)
    endwin()
    win.x = x
    win.y = y
    return win

proc getHeader(cmd: string, n, x: int): string =
    let date = getLocalTime getTime()
    let left  = "Every " & $n & "s: " & cmd
    let right = format(date, "ddd',' dd MMM yyyy HH:mm:ss")
    let space = x - (left.len + right.len)
    result = left & " " & right
    if space > 0:
        result = left & " ".repeat(space) & right
    return

proc getOutput(cmd: string): string =
    let (outp, _) = execCmdEx cmd
    return outp

proc echo(inp: varargs[string]) =
    var outp = ""
    for s in items inp:
        if s != nil:
            outp = outp & s
    if outp.len > 0:
        discard execCmd("echo '" & outp & "'")

proc outputToScreen(outp, cmd:string, ni: int) =
    let header = 2
    echo(getHeader(cmd, ni, win.x), "\n")
    var lignes = split(outp, "\n")
    for i, v in lignes:
        if i < (win.y - header) - 1:
            echo v

proc exec(cmd: string, n: int) =
    discard execCmd "clear"
    let output = getOutput cmd
    outputToScreen(output, cmd, n)

proc asyncExec(cmd: string, ni: int) =
    let n = float ni
    proc onAsyncCompleted(outp: string, cmd: string, bef: float) =
        let bet = toSeconds(getTime()) - bef
        let slpSec = int(math.ceil((n - bet) * 1000))
        if slpSec > 0:
            sleep slpSec
        discard execCmd "clear"
        outputToScreen(outp, cmd, ni)
        asyncExec(cmd, ni)
    let bef = toSeconds getTime()
    let outp = ^(spawn getOutput cmd)
    onAsyncCompleted(outp, cmd, bef)

proc loop(cmd: string, n: int) =
    while true:
        exec(cmd, n)
        sleep(n * 1000)

proc loopAsync(cmd: string, n: int) =
    exec(cmd, n)
    asyncExec(cmd, n)

when isMainModule:
    var
        cmd: string
        n: int
        async, vs: bool = false
    setControlCHook handleControlC
    win = getScreenSize()
    for kind, key, val in getopt():
        case kind
        of cmdArgument:
            cmd = key
        of cmdLongOption, cmdShortOption:
            case key
            of "n":
                n = parseInt val
            of "async":
                async = true
            # TODO
            of "vs", "variable-screen":
                vs = true
            else: discard
        of cmdEnd:
            discard
    if cmd != nil and n != 0:
        if async:
            loopAsync(cmd, n)
        else:
            loop(cmd, n)
