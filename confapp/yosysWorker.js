// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// yosysWorker.js
// Javascript routine to be used in a worker for loading Yosys WebAsm
//
// 2024 July 3
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

function LoadModule() {
    return import('https://cdn.jsdelivr.net/npm/@yowasp/yosys/gen/bundle.js');
}

// Call the function to load the module
 onmessage = async function(e) {
    moduleName = e.data.module;
    verilogStr = e.data.verilog;

    var scriptStr = `
read_verilog -sv input.v
hierarchy -top ${moduleName}
proc; opt
write_json -compat-int out.json`;
    module = await LoadModule();
   filesOut = await module.runYosys(["-Q", "-q", "-T", "-s", "cmd.tcl"], {"input.v": `${verilogStr}`, "cmd.tcl": `${scriptStr}`})
    var fileContents = filesOut['out.json'];
    this.postMessage(fileContents);
 }

 // Can we setup this JS file using the JS commands in dart.


